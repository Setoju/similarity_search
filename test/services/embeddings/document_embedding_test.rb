require "test_helper"

class Embeddings::DocumentEmbeddingTest < ActiveSupport::TestCase
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    stub_ollama(@sample_embedding)
  end

  test "generates embedding for document with content" do
    document = Document.new(content: "Test content")
    Embeddings::DocumentEmbedding.new(document).call

    assert_kind_of Array, document.embedding
    assert_equal 768, document.embedding.length
  end

  test "does not generate embedding for blank content" do
    document = Document.new(content: "")
    Embeddings::DocumentEmbedding.new(document).call

    assert_nil document.embedding
  end

  test "normalizes content before embedding" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .with(body: hash_including("prompt" => "hello world"))
      .to_return(status: 200, body: { embedding: @sample_embedding }.to_json)

    document = Document.new(content: "  HELLO   WORLD  ")
    Embeddings::DocumentEmbedding.new(document).call

    assert_requested(:post, "http://localhost:11434/api/embeddings")
  end

end
