require "test_helper"

class ContextualRetrieval::ChunkContextualizerTest < ActiveSupport::TestCase
  setup do
    @document_content = "Ruby is a dynamic programming language. It was created by Yukihiro Matsumoto. Ruby is popular for web development."
    @chunks = [
      { content: "Ruby is a dynamic programming language.", start_char: 0, end_char: 40 },
      { content: "It was created by Yukihiro Matsumoto.", start_char: 41, end_char: 78 }
    ]
  end

  test "adds context to each chunk using ollama" do
    stub_request(:post, "http://localhost:11434/api/generate")
      .to_return(
        status: 200,
        body: { response: "This chunk introduces the Ruby language." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal 2, result.size
    assert_equal "This chunk introduces the Ruby language.", result[0][:context]
    assert_equal "This chunk introduces the Ruby language.", result[1][:context]
    # Original keys are preserved
    assert_equal 0, result[0][:start_char]
    assert_equal 40, result[0][:end_char]
    assert_equal "Ruby is a dynamic programming language.", result[0][:content]

    assert_requested(
      :post,
      "http://localhost:11434/api/generate",
      times: 2
    ) do |request|
      parsed = JSON.parse(request.body)
      parsed["model"] == "gemma3:1b" && parsed["stream"] == false
    end
  end

  test "returns chunks unchanged when array is empty" do
    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, [])
    assert_equal [], result
  end

  test "sets empty context when ollama generation fails" do
    stub_request(:post, "http://localhost:11434/api/generate")
      .to_raise(Faraday::ConnectionFailed.new("Refused"))

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal 2, result.size
    result.each { |chunk| assert_equal "", chunk[:context] }
  end

  test "strips whitespace from generated context" do
    stub_request(:post, "http://localhost:11434/api/generate")
      .to_return(
        status: 200,
        body: { response: "  Some context with spaces.  \n" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = ContextualRetrieval::ChunkContextualizer.call(@document_content, @chunks)

    assert_equal "Some context with spaces.", result[0][:context]
  end
end
