require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "creates with pending index_status" do
    document = Document.create!(content: "Test document")
    assert_equal "pending", document.index_status
  end

  test "enqueues embedding job on create" do
    assert_enqueued_with(job: DocumentEmbeddingJob) do
      Document.create!(content: "Test document")
    end
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
