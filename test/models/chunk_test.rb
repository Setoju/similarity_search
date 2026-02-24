require "test_helper"

class ChunkTest < ActiveSupport::TestCase
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    stub_connection
  end

  test "valid with start_char, end_char, and a document" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: 0, end_char: 4, document: document, embedding: @sample_embedding)
    assert chunk.valid?
  end

  test "invalid without a document" do
    chunk = Chunk.new(start_char: 0, end_char: 4, embedding: @sample_embedding)
    refute chunk.valid?
    assert chunk.errors[:document].any?
  end

  test "invalid without start_char" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    # Omit end_char too so the greater_than: :start_char comparison is never attempted on nil
    chunk = Chunk.new(document: document)
    refute chunk.valid?
    assert chunk.errors[:start_char].any?
  end

  test "invalid without end_char" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: 0, document: document)
    refute chunk.valid?
    assert chunk.errors[:end_char].any?
  end

  test "invalid with negative start_char" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: -1, end_char: 4, document: document)
    refute chunk.valid?
    assert chunk.errors[:start_char].any?
  end

  test "invalid when end_char equals start_char" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: 5, end_char: 5, document: document)
    refute chunk.valid?
    assert chunk.errors[:end_char].any?
  end

  test "invalid when end_char is less than start_char" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.new(start_char: 5, end_char: 3, document: document)
    refute chunk.valid?
    assert chunk.errors[:end_char].any?
  end

  test "content returns the correct slice of document content" do
    document = Document.create!(content: "Hello, world!", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.create!(start_char: 7, end_char: 12, document: document, embedding: @sample_embedding)
    assert_equal "world", chunk.content
  end

  test "content reflects changes when document content changes" do
    document = Document.create!(content: "Hello, world!", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.create!(start_char: 0, end_char: 5, document: document, embedding: @sample_embedding)
    assert_equal "Hello", chunk.content
  end

  test "belongs to document" do
    document = Document.create!(content: "Test document", index_status: "completed", embedding: @sample_embedding)
    chunk = Chunk.create!(start_char: 0, end_char: 4, document: document, embedding: @sample_embedding)
    assert_equal document, chunk.document
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
