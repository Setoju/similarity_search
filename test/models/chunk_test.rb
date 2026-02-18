require "test_helper"

class ChunkTest < ActiveSupport::TestCase
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    stub_connection
  end

  test "valid with content and document" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: 0, end_char: 4, document: document, embedding: @sample_embedding)
    assert chunk.valid?
  end

  private

  def stub_connection
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_return(
        status: 200,
        body: { embedding: @sample_embedding }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
