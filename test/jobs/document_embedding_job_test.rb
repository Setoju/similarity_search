require "test_helper"

class DocumentEmbeddingJobTest < ActiveJob::TestCase
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    ENV["GOOGLE_API_KEY"] = "test-api-key"
    stub_connection
    stub_gemini_cache
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "enqueues and performs job successfully" do
    document = Document.create!(content: "Test document for embedding job", index_status: "pending")

    assert_enqueued_with(job: DocumentEmbeddingJob, args: [document.id]) do
      DocumentEmbeddingJob.perform_later(document.id)
    end

    perform_enqueued_jobs

    document.reload
    assert_equal "completed", document.index_status
    assert_kind_of Array, document.embedding
    assert_equal 768, document.embedding.length
  end

  test "creates chunks" do
    document = Document.create!(content: "Hello world. This is a test. Another sentence here.")
    
    perform_enqueued_jobs
    
    document.reload
    assert_equal "completed", document.index_status
    assert document.chunks.any?, "Should create chunks"
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
