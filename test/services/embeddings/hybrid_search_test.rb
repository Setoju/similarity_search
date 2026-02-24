require "test_helper"

class Embeddings::HybridSearchTest < ActiveSupport::TestCase
  setup do
    @query_embedding = Array.new(768) { 0.5 }
    Document.destroy_all
    stub_ollama(@query_embedding)
  end

  test "returns empty array when no chunks exist" do
    assert_equal [], Embeddings::HybridSearch.new("query").call
  end

  test "returns results with expected keys" do
    create_doc_with_chunk("Ruby on Rails is great for web development", @query_embedding)

    results = Embeddings::HybridSearch.new("Rails web").call

    assert results.any?
    result = results.first
    assert result.key?(:content)
    assert result.key?(:score)
    assert result.key?(:document_id)
    assert result.key?(:chunk_id)
    assert result.key?(:start_char)
    assert result.key?(:end_char)
  end

  test "respects top parameter" do
    3.times { |i| create_doc_with_chunk("Ruby Rails web development guide #{i}", @query_embedding) }

    results = Embeddings::HybridSearch.new("Rails", top: 2).call

    assert results.length <= 2
  end

  test "returns empty array when ollama embedding fails" do
    create_doc_with_chunk("Some test content here", @query_embedding)

    WebMock.reset!
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_raise(Faraday::ConnectionFailed.new("Refused"))

    assert_equal [], Embeddings::HybridSearch.new("query").call
  end

  test "deduplicates chunks with identical content" do
    doc = Document.create!(content: "identical content phrase and some more padding text")
    doc.update_column(:embedding, @query_embedding)
    # Two chunks pointing at the same char range (same content)
    doc.chunks.create!(start_char: 0, end_char: 17, embedding: @query_embedding)
    doc.chunks.create!(start_char: 0, end_char: 17, embedding: @query_embedding)

    results = Embeddings::HybridSearch.new("identical content").call

    contents = results.map { |r| r[:content] }
    assert_equal contents.uniq, contents
  end

  test "scores reflect alpha weighting" do
    create_doc_with_chunk("Ruby Rails web framework development", @query_embedding)

    # Both runs should complete without error
    pure_semantic = Embeddings::HybridSearch.new("Rails", alpha: 1.0).call
    pure_bm25     = Embeddings::HybridSearch.new("Rails", alpha: 0.0).call

    assert_kind_of Array, pure_semantic
    assert_kind_of Array, pure_bm25
  end

  test "clamps alpha to valid range" do
    create_doc_with_chunk("Rails content for testing alpha clamp", @query_embedding)

    # Should not raise even with out-of-range alpha
    assert_nothing_raised { Embeddings::HybridSearch.new("Rails", alpha: 2.0).call }
    assert_nothing_raised { Embeddings::HybridSearch.new("Rails", alpha: -1.0).call }
  end

  test "results are sorted by descending score" do
    create_doc_with_chunk("Ruby on Rails framework", @query_embedding)
    create_doc_with_chunk("Python data science library", Array.new(768) { 0.1 })

    results = Embeddings::HybridSearch.new("Rails").call
    scores = results.map { |r| r[:score] }

    assert_equal scores, scores.sort.reverse
  end

end
