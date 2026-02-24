require "test_helper"

class Reranking::LlmRerankerTest < ActiveSupport::TestCase
  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
    @candidates = [
      { content: "Ruby on Rails is a web framework", score: 0.9 },
      { content: "Python is used in data science",   score: 0.7 },
      { content: "JavaScript runs in browsers",      score: 0.5 }
    ]
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "returns empty array for empty candidates" do
    assert_equal [], Reranking::LlmReranker.new("query", []).call
  end

  test "applies LLM scores and filters below threshold" do
    stub_gemini_response("[9, 3, 6]")

    results = Reranking::LlmReranker.new("Rails web framework", @candidates).call

    # 9 >= 5 (kept), 3 < 5 (filtered), 6 >= 5 (kept)
    assert_equal 2, results.length
    assert_equal 9, results.first[:rerank_score]
    assert_equal 6, results.last[:rerank_score]
  end

  test "results are sorted by descending rerank score" do
    stub_gemini_response("[4, 9, 6]")

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 0).call

    scores = results.map { |r| r[:rerank_score] }
    assert_equal scores, scores.sort.reverse
  end

  test "filters all results below a high threshold" do
    stub_gemini_response("[3, 2, 1]")

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 5).call

    assert_equal [], results
  end

  test "falls back to score 10 for all when Gemini is unavailable" do
    stub_request(:post, GEMINI_URL).to_raise(Faraday::ConnectionFailed.new("Refused"))

    results = Reranking::LlmReranker.new("query", @candidates).call

    assert_equal 3, results.length
    results.each { |r| assert_equal 10, r[:rerank_score] }
  end

  test "falls back when LLM returns fewer scores than candidates" do
    stub_gemini_response("[8]")  # Only 1 score for 3 candidates

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 0).call

    results.each { |r| assert_equal 10, r[:rerank_score] }
  end

  test "falls back when LLM response contains no score array" do
    stub_gemini_response("I cannot evaluate these passages at this time.")

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 0).call

    results.each { |r| assert_equal 10, r[:rerank_score] }
  end

  test "clamps scores to 0-10 range" do
    stub_gemini_response("[15, 12, 7]")  # 15 and 12 exceed maximum

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 0).call

    results.each do |r|
      assert r[:rerank_score] >= 0 && r[:rerank_score] <= 10,
             "Score #{r[:rerank_score]} is outside the valid range"
    end
  end

  test "preserves original result keys alongside rerank_score" do
    stub_gemini_response("[8, 6, 4]")

    results = Reranking::LlmReranker.new("query", @candidates, threshold: 0).call

    results.each do |r|
      assert r.key?(:content)
      assert r.key?(:score)
      assert r.key?(:rerank_score)
    end
  end

  test "threshold is clamped to 0-10 range" do
    stub_gemini_response("[8, 3, 6]")

    # threshold: 15 should behave like threshold: 10 — only scores of 10 pass
    results = Reranking::LlmReranker.new("query", @candidates, threshold: 15).call
    assert_equal [], results
  end
end
