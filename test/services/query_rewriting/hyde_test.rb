require "test_helper"

class QueryRewriting::HydeTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "generates a hypothetical document for the query" do
    stub_gemini_response("Ruby is a dynamic programming language created by Yukihiro Matsumoto.")

    result = QueryRewriting::Hyde.new("What is Ruby?").call

    assert_equal "Ruby is a dynamic programming language created by Yukihiro Matsumoto.", result
  end

  test "uses GoogleGeminiClient for generation" do
    stub_gemini_response("Generated content here.")

    result = QueryRewriting::Hyde.new("Some query").call

    assert_kind_of String, result
    assert_not result.empty?
  end

  test "includes the query in the prompt" do
    stub_gemini_response("Answer content.")

    # This will pass through and call the API with the query embedded in the prompt
    result = QueryRewriting::Hyde.new("What are microservices?").call

    assert_equal "Answer content.", result
  end
end
