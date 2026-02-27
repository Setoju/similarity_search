require "test_helper"

class RagEval::MetricsTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # keyword_recall
  # ---------------------------------------------------------------------------
  test "keyword_recall returns 1.0 when all keywords present" do
    answer = "Bubble sort has a worst-case time complexity of O(n squared)"
    keywords = ["bubble sort", "O(n squared)"]
    assert_in_delta 1.0, RagEval::Metrics.keyword_recall(answer, keywords)
  end

  test "keyword_recall returns 0.0 when no keywords present" do
    answer = "This answer talks about something unrelated"
    keywords = ["gradient descent", "cost function"]
    assert_in_delta 0.0, RagEval::Metrics.keyword_recall(answer, keywords)
  end

  test "keyword_recall returns partial score" do
    answer = "Merge sort was invented by someone long ago"
    keywords = ["merge sort", "John von Neumann", "1945"]
    assert_in_delta 1.0 / 3, RagEval::Metrics.keyword_recall(answer, keywords), 0.01
  end

  test "keyword_recall is case insensitive" do
    answer = "BUBBLE SORT is simple"
    keywords = ["bubble sort"]
    assert_in_delta 1.0, RagEval::Metrics.keyword_recall(answer, keywords)
  end

  test "keyword_recall returns 1.0 for empty keywords" do
    assert_in_delta 1.0, RagEval::Metrics.keyword_recall("any answer", [])
  end

  # ---------------------------------------------------------------------------
  # token_f1
  # ---------------------------------------------------------------------------
  test "token_f1 returns 1.0 for identical texts" do
    text = "bubble sort has quadratic time complexity"
    assert_in_delta 1.0, RagEval::Metrics.token_f1(text, text)
  end

  test "token_f1 returns 0.0 for completely different texts" do
    assert_in_delta 0.0, RagEval::Metrics.token_f1("cat dog fish", "xyz abc qwe"), 0.01
  end

  test "token_f1 returns partial score for overlapping texts" do
    answer = "bubble sort is a simple sorting algorithm"
    expected = "bubble sort is inefficient for large datasets"
    score = RagEval::Metrics.token_f1(answer, expected)
    assert score > 0.0
    assert score < 1.0
  end

  test "token_f1 handles empty strings" do
    assert_in_delta 0.0, RagEval::Metrics.token_f1("", "something")
    assert_in_delta 0.0, RagEval::Metrics.token_f1("something", "")
  end

  # ---------------------------------------------------------------------------
  # factual_overlap
  # ---------------------------------------------------------------------------
  test "factual_overlap returns 1.0 when answer contains all expected tokens" do
    expected = "merge sort uses divide and conquer"
    answer = "merge sort uses the divide and conquer approach effectively"
    assert_in_delta 1.0, RagEval::Metrics.factual_overlap(answer, expected)
  end

  test "factual_overlap returns 0.0 for no overlap" do
    expected = "quantum computing entanglement"
    answer = "bubble sort is simple"
    assert_in_delta 0.0, RagEval::Metrics.factual_overlap(answer, expected), 0.01
  end

  # ---------------------------------------------------------------------------
  # retrieval_precision
  # ---------------------------------------------------------------------------
  test "retrieval_precision returns 1.0 when all sources are relevant" do
    sources = [
      { content: "Bubble sort has O(n squared) complexity" },
      { content: "Bubble sort compares adjacent elements" }
    ]
    keywords = ["bubble sort"]
    assert_in_delta 1.0, RagEval::Metrics.retrieval_precision(sources, keywords)
  end

  test "retrieval_precision returns 0.0 for no relevant sources" do
    sources = [{ content: "Unrelated content about cooking recipes" }]
    keywords = ["bubble sort"]
    assert_in_delta 0.0, RagEval::Metrics.retrieval_precision(sources, keywords)
  end

  test "retrieval_precision returns 0.5 for half relevant sources" do
    sources = [
      { content: "Bubble sort is simple" },
      { content: "Pasta recipe instructions" }
    ]
    keywords = ["bubble sort"]
    assert_in_delta 0.5, RagEval::Metrics.retrieval_precision(sources, keywords)
  end

  test "retrieval_precision handles nil and empty sources" do
    assert_in_delta 0.0, RagEval::Metrics.retrieval_precision(nil, ["test"])
    assert_in_delta 0.0, RagEval::Metrics.retrieval_precision([], ["test"])
  end

  # ---------------------------------------------------------------------------
  # retrieval_hit?
  # ---------------------------------------------------------------------------
  test "retrieval_hit? returns true when at least one source is relevant" do
    sources = [
      { content: "Unrelated stuff" },
      { content: "Merge sort is a divide-and-conquer algorithm" }
    ]
    assert RagEval::Metrics.retrieval_hit?(sources, ["merge sort"])
  end

  test "retrieval_hit? returns false when no source is relevant" do
    sources = [{ content: "completely unrelated content" }]
    refute RagEval::Metrics.retrieval_hit?(sources, ["merge sort"])
  end

  # ---------------------------------------------------------------------------
  # overall_score
  # ---------------------------------------------------------------------------
  test "overall_score returns a score between 0 and 100" do
    score = RagEval::Metrics.overall_score(
      answer: "Bubble sort has O(n squared) complexity",
      expected_answer: "Bubble sort has a worst-case time complexity of O(n squared)",
      expected_keywords: ["O(n squared)", "bubble sort"]
    )
    assert score >= 0
    assert score <= 100
  end

  test "overall_score gives high score for matching answer" do
    answer = "Bubble sort has a worst-case and average time complexity of O(n squared)"
    expected = "Bubble sort has a worst-case and average time complexity of O(n squared)"
    keywords = ["O(n squared)", "bubble sort"]

    score = RagEval::Metrics.overall_score(
      answer: answer,
      expected_answer: expected,
      expected_keywords: keywords
    )
    assert score >= 70, "Expected high score for matching answer, got #{score}"
  end

  test "overall_score gives low score for unrelated answer" do
    score = RagEval::Metrics.overall_score(
      answer: "Quantum physics studies subatomic particles",
      expected_answer: "Bubble sort has O(n squared) time complexity",
      expected_keywords: ["O(n squared)", "bubble sort"]
    )
    assert score < 30, "Expected low score for unrelated answer, got #{score}"
  end
end
