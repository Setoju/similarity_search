require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
    Document.destroy_all
    stub_ollama_success
  end

  test "index returns all documents" do
    Document.create!(content: "First document")
    Document.create!(content: "Second document")

    get documents_url
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 2, json.length
  end

  test "create saves document and returns it" do
    assert_difference("Document.count", 1) do
      post documents_url, params: { document: { content: "New document" } }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "New document", json["content"]
  end

  test "search returns matching documents" do
    doc = Document.create!(content: "Ruby programming")
    doc.update_column(:embedding, @sample_embedding)

    post search_documents_url, params: { query: "ruby" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
  end

  test "search returns empty array for no matches" do
    post search_documents_url, params: { query: "test" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal [], json
  end

  test "clear removes all documents" do
    Document.create!(content: "Document to delete")

    assert_difference("Document.count", -1) do
      delete clear_documents_url
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "All documents cleared", json["message"]
  end

  test "index_status returns correct counts" do
    Document.create!(content: "Pending document")

    get index_status_documents_url
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1, json["pending"]
    assert_equal 0, json["processing"]
    assert_equal 0, json["completed"]
    assert_equal 0, json["failed"]
  end

  test "sentence_search returns relevant sentences" do
    doc = Document.create!(content: "This is a test document. It contains multiple sentences.")
    doc.update_column(:embedding, @sample_embedding)
    doc.update_column(:index_status, "completed")
    chunk = doc.chunks.create!(start_char: 0, end_char: doc.content.length, embedding: @sample_embedding)
    sentemce1 = chunk.sentences.create!(start_char: 0, end_char: 24, document_id: doc.id, embedding: @sample_embedding)
    sentence2 = chunk.sentences.create!(start_char: 25, end_char: 57, document_id: doc.id, embedding: @sample_embedding) 

    post sentence_search_documents_url, params: { query: "test" }
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal "This is a test document.", json.first["content"]
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
