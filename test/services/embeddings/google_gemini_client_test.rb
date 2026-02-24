require "test_helper"

class Embeddings::GoogleGeminiClientTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-api-key"
    @client = Embeddings::GoogleGeminiClient.new
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "raises error when GOOGLE_API_KEY is not set" do
    ENV.delete("GOOGLE_API_KEY")
    error = assert_raises(RuntimeError) { Embeddings::GoogleGeminiClient.new }
    assert_match(/GOOGLE_API_KEY/, error.message)
  end

  test "returns generated text on successful response" do
    stub_gemini_response("The answer is 42.")

    result = @client.generate("What is the answer?")

    assert_equal "The answer is 42.", result
  end

  test "raises error when candidates array is empty" do
    stub_request(:post, GEMINI_URL)
      .to_return(
        status: 200,
        body: { candidates: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/No candidates/, error.message)
  end

  test "raises error when response body contains an error key" do
    stub_request(:post, GEMINI_URL)
      .to_return(
        status: 200,
        body: { error: { message: "Model overloaded" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/Model overloaded/, error.message)
  end

  test "raises error on HTTP 4xx client error" do
    stub_request(:post, GEMINI_URL)
      .to_return(
        status: 403,
        body: { error: { message: "API key not valid" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/Google Gemini API error/, error.message)
  end

  test "raises error on timeout" do
    stub_request(:post, GEMINI_URL).to_raise(Faraday::TimeoutError.new("Timeout"))

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/timed out/, error.message)
  end

  test "raises error on connection failure" do
    stub_request(:post, GEMINI_URL).to_raise(Faraday::ConnectionFailed.new("Refused"))

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/Cannot connect to Google Gemini/, error.message)
  end

  test "raises error on invalid JSON response" do
    stub_request(:post, GEMINI_URL)
      .to_return(status: 200, body: "not valid json {{")

    error = assert_raises(RuntimeError) { @client.generate("query") }
    assert_match(/Invalid JSON/, error.message)
  end

  test "raises error when text part is missing from response" do
    body = {
      candidates: [
        { content: { parts: [] } }
      ]
    }.to_json

    stub_request(:post, GEMINI_URL)
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @client.generate("query") }
  end

end
