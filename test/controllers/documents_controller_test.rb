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
