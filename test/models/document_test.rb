require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    stub_ollama_success
  end

  test "valid with content" do
    document = Document.new(content: "Valid content")
    assert document.valid?
  end

  test "invalid without content" do
    document = Document.new(content: nil)
    refute document.valid?
    assert_includes document.errors[:content], "can't be blank"
  end

  test "invalid with empty content" do
    document = Document.new(content: "")
    refute document.valid?
  end

  test "generates embedding on create" do
    document = Document.create!(content: "Test document")
    assert_kind_of Array, document.embedding
    assert_equal 768, document.embedding.length
  end

  test "does not regenerate embedding on update" do
    document = Document.create!(content: "Original")
    original_embedding = document.embedding.dup

    document.update!(content: "Updated content")
    assert_equal original_embedding, document.embedding
  end

  private

  def stub_ollama_success
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_return(
        status: 200,
        body: { embedding: @sample_embedding }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
