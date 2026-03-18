require "test_helper"

class QueryRewriting::DecomposerTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "returns array of subqueries when query can be decomposed" do
    stub_gemini_response("What are the benefits of microservices?\nWhat are the drawbacks of microservices?")

    result = QueryRewriting::Decomposer.new("What are the pros and cons of microservices?").call

    assert_kind_of Array, result
    assert_equal 2, result.length
    assert_includes result, "What are the benefits of microservices?"
    assert_includes result, "What are the drawbacks of microservices?"
  end

  test "returns single-element array when query is already simple" do
    stub_gemini_response("What is Ruby?")

    result = QueryRewriting::Decomposer.new("What is Ruby?").call

    assert_kind_of Array, result
    assert_equal 1, result.length
    assert_equal "What is Ruby?", result.first
  end

  test "handles numbered responses by stripping numbers" do
    stub_gemini_response("1. First subquery here\n2. Second subquery here")

    result = QueryRewriting::Decomposer.new("complex query").call

    assert_equal ["First subquery here", "Second subquery here"], result
  end

  test "returns original query if response is empty" do
    stub_gemini_response("")

    result = QueryRewriting::Decomposer.new("My original query").call

    assert_equal ["My original query"], result
  end

  test "filters out empty lines from response" do
    stub_gemini_response("First query\n\nSecond query\n\n")

    result = QueryRewriting::Decomposer.new("complex query").call

    assert_equal ["First query", "Second query"], result
  end
end
