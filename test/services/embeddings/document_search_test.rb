require "test_helper"

class Embeddings::DocumentSearchTest < ActiveSupport::TestCase
  setup do
    @query_embedding = Array.new(768) { 0.5 }
    Document.destroy_all
    stub_ollama(@query_embedding)
  end

  test "returns documents sorted by similarity" do
    # Create docs with different embeddings
    # Query embedding is all 0.5s, so identical vector should rank first
    identical = create_document_with_embedding("Identical", Array.new(768) { 0.5 })
    different = create_document_with_embedding("Different", Array.new(768) { |i| i < 384 ? 1.0 : 0.0 })

    results = Embeddings::DocumentSearch.new("query").call

    result_ids = results.map { |r| r[:id] }
    assert_includes result_ids, identical.id
    assert_includes result_ids, different.id
    # Identical embedding should be first (similarity = 1.0)
    assert_equal identical.id, results.first[:id]
  end

  test "returns top n results" do
    5.times { |i| create_document_with_embedding("Doc #{i}", Array.new(768) { rand }) }

    results = Embeddings::DocumentSearch.new("query", top: 3).call
    assert_equal 3, results.length
  end

  test "excludes documents without embeddings" do
    doc_with = create_document_with_embedding("With embedding", Array.new(768) { 0.5 })
    doc_without = Document.create!(content: "Without embedding")
    doc_without.update_column(:embedding, nil)

    results = Embeddings::DocumentSearch.new("query").call

    result_ids = results.map { |r| r[:id] }
    assert_includes result_ids, doc_with.id
    refute_includes result_ids, doc_without.id
  end

  test "returns empty array when no documents exist" do
    results = Embeddings::DocumentSearch.new("query").call
    assert_equal [], results
  end

  private

  def create_document_with_embedding(content, embedding)
    doc = Document.create!(content: content)
    doc.update_column(:embedding, embedding)
    doc
  end
end
