require "test_helper"

class Embeddings::OllamaClientTest < ActiveSupport::TestCase
  setup do
    @client = Embeddings::OllamaClient.new
    @sample_embedding = Array.new(768) { rand(-1.0..1.0) }
  end

  test "returns embedding array on successful response" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_return(
        status: 200,
        body: { embedding: @sample_embedding }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.embed("test text")
    assert_kind_of Array, result
    assert_equal 768, result.length
  end

  test "raises error on ollama error response" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_return(
        status: 400,
        body: { error: "model not found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(RuntimeError) { @client.embed("test") }
    assert_match(/Ollama error/, error.message)
  end

  test "raises error on connection failure" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    error = assert_raises(RuntimeError) { @client.embed("test") }
    assert_match(/Cannot connect to Ollama/, error.message)
  end

  test "raises error on timeout" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_raise(Faraday::TimeoutError.new("Timeout"))

    error = assert_raises(RuntimeError) { @client.embed("test") }
    assert_match(/timed out/, error.message)
  end

  test "raises error on invalid JSON response" do
    stub_request(:post, "http://localhost:11434/api/embeddings")
      .to_return(status: 200, body: "invalid json")

    error = assert_raises(RuntimeError) { @client.embed("test") }
    assert_match(/Invalid JSON/, error.message)
  end
end
