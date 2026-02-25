require "test_helper"

class ContextualRetrieval::ChunkContextualizerTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-api-key"
    @document_content = "Ruby is a dynamic programming language. It was created by Yukihiro Matsumoto. Ruby is popular for web development."
    @chunks = [
      { content: "Ruby is a dynamic programming language.", start_char: 0, end_char: 40 },
      { content: "It was created by Yukihiro Matsumoto.", start_char: 41, end_char: 78 }
    ]
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "adds context to each chunk using cached content" do
    stub_gemini_cache(context_text: "This chunk introduces the Ruby language.")

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal 2, result.size
    assert_equal "This chunk introduces the Ruby language.", result[0][:context]
    assert_equal "This chunk introduces the Ruby language.", result[1][:context]
    # Original keys are preserved
    assert_equal 0, result[0][:start_char]
    assert_equal 40, result[0][:end_char]
    assert_equal "Ruby is a dynamic programming language.", result[0][:content]
  end

  test "returns chunks unchanged when array is empty" do
    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, [])
    assert_equal [], result
  end

  test "falls back to direct generation when cache creation fails" do
    # Cache creation fails
    stub_request(:post, GEMINI_CACHE_URL)
      .to_return(status: 400, body: { error: { message: "Document too small" } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    # Direct generation succeeds via the standard model
    stub_gemini_response("Fallback context for this chunk.")

    # Cache delete should not be called (no cache was created)
    stub_request(:delete, GEMINI_CACHE_DELETE_URL).to_return(status: 200)

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal 2, result.size
    assert_equal "Fallback context for this chunk.", result[0][:context]
  end

  test "sets empty context when both cached and direct generation fail" do
    # Cache creation fails
    stub_request(:post, GEMINI_CACHE_URL)
      .to_return(status: 400, body: { error: { message: "Error" } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    # Direct generation also fails
    stub_request(:post, GEMINI_URL).to_raise(Faraday::ConnectionFailed.new("Refused"))

    stub_request(:delete, GEMINI_CACHE_DELETE_URL).to_return(status: 200)

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal 2, result.size
    result.each { |chunk| assert_equal "", chunk[:context] }
  end

  test "cleans up cached content after successful contextualization" do
    stub_gemini_cache(context_text: "Context text.")
    delete_stub = stub_request(:delete, GEMINI_CACHE_DELETE_URL).to_return(status: 200)

    ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_requested(delete_stub)
  end

  test "strips whitespace from generated context" do
    stub_gemini_cache(context_text: "  Some context with spaces.  \n")

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal "Some context with spaces.", result[0][:context]
  end
end
