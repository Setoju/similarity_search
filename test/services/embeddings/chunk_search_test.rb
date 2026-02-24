require "test_helper"

class Embeddings::ChunkSearchTest < ActiveSupport::TestCase
  setup do
    @query_embedding = Array.new(768) { 0.5 }
    Document.destroy_all
    stub_ollama(@query_embedding)
  end

  test "returns empty array when no chunks exist" do
    assert_equal [], Embeddings::ChunkSearch.new("query").call
  end

  test "returns matching chunks above threshold" do
    doc = create_doc_with_chunk("Ruby on Rails web framework guide", Array.new(768) { 0.5 })

    results = Embeddings::ChunkSearch.new("query").call

    assert results.any?
    assert_equal doc.chunks.first.id, results.first[:chunk_id]
  end

  test "excludes chunks below threshold" do
    # A zero vector has cosine similarity of 0.0 with the query vector — below default threshold 0.4
    doc = Document.create!(content: "A" * 50)
    doc.update_column(:embedding, @query_embedding)
    # all-zero embedding → cosine similarity = 0.0 → filtered out
    low_chunk = doc.chunks.create!(start_char: 0, end_char: 10, embedding: Array.new(768) { 0.0 })

    results = Embeddings::ChunkSearch.new("query").call

    refute_includes results.map { |r| r[:chunk_id] }, low_chunk.id
  end

  test "result contains expected keys" do
    create_doc_with_chunk("Hello world test content here", Array.new(768) { 0.5 })

    result = Embeddings::ChunkSearch.new("query").call.first

    assert result.key?(:content)
    assert result.key?(:score)
    assert result.key?(:document_id)
    assert result.key?(:chunk_id)
    assert result.key?(:start_char)
    assert result.key?(:end_char)
  end

  test "respects top parameter" do
    3.times { |i| create_doc_with_chunk("Content number #{i} here", Array.new(768) { 0.5 }) }

    results = Embeddings::ChunkSearch.new("query", top: 2).call

    assert results.length <= 2
  end

  test "filters out chunks below default threshold" do
    # All-zero embedding has cosine similarity of 0.0 with the query vector
    create_doc_with_chunk("Low similarity content here", Array.new(768) { 0.0 })

    results = Embeddings::ChunkSearch.new("query").call

    assert_equal [], results
  end

  test "uses euclidean strategy when specified" do
    create_doc_with_chunk("Euclidean distance test content", Array.new(768) { 0.5 })

    results = Embeddings::ChunkSearch.new("query", "euclidean", threshold: 0.0).call

    assert results.any?
  end

  test "deduplicates chunks with identical content" do
    doc = Document.create!(content: "same content here and more padding text")
    doc.update_column(:embedding, @query_embedding)
    doc.chunks.create!(start_char: 0, end_char: 12, embedding: @query_embedding)
    doc.chunks.create!(start_char: 0, end_char: 12, embedding: @query_embedding)

    results = Embeddings::ChunkSearch.new("query").call

    contents = results.map { |r| r[:content] }
    assert_equal contents.uniq, contents
  end

  test "results are sorted by descending score" do
    create_doc_with_chunk("High similarity content", Array.new(768) { 0.5 })

    results = Embeddings::ChunkSearch.new("query", threshold: 0.0).call
    scores = results.map { |r| r[:score] }

    assert_equal scores, scores.sort.reverse
  end

end
