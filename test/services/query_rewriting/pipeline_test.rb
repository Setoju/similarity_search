require "test_helper"

class QueryRewriting::PipelineTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "returns single query object when no rewriting enabled" do
    result = QueryRewriting::Pipeline.new("What is Ruby?").call

    assert_kind_of Array, result
    assert_equal 1, result.length
    assert_equal "What is Ruby?", result.first[:original]
    assert_nil result.first[:hyde_doc]
  end

  test "applies HyDE when hyde option is true" do
    stub_gemini_response("Ruby is a programming language.")

    result = QueryRewriting::Pipeline.new("What is Ruby?", hyde: true).call

    assert_equal 1, result.length
    assert_equal "What is Ruby?", result.first[:original]
    assert_equal "Ruby is a programming language.", result.first[:hyde_doc]
  end

  test "applies decomposition when decompose option is true" do
    stub_gemini_response("Question one?\nQuestion two?")

    result = QueryRewriting::Pipeline.new("Complex query", decompose: true).call

    assert_equal 2, result.length
    assert_equal "Question one?", result[0][:original]
    assert_equal "Question two?", result[1][:original]
    assert_nil result[0][:hyde_doc]
    assert_nil result[1][:hyde_doc]
  end

  test "applies both decomposition and HyDE when both options are true" do
    # First call for decomposition
    stub_request(:post, GEMINI_URL)
      .to_return(
        { status: 200, body: gemini_body("Subquery A\nSubquery B"), headers: { "Content-Type" => "application/json" } },
        { status: 200, body: gemini_body("HyDE doc for A"), headers: { "Content-Type" => "application/json" } },
        { status: 200, body: gemini_body("HyDE doc for B"), headers: { "Content-Type" => "application/json" } }
      )

    result = QueryRewriting::Pipeline.new("Complex query", decompose: true, hyde: true).call

    assert_equal 2, result.length
    assert_equal "Subquery A", result[0][:original]
    assert_equal "Subquery B", result[1][:original]
    assert_equal "HyDE doc for A", result[0][:hyde_doc]
    assert_equal "HyDE doc for B", result[1][:hyde_doc]
  end

  private

  def gemini_body(text)
    { candidates: [{ content: { parts: [{ text: text }] } }] }.to_json
  end
end
