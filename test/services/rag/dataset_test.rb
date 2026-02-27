require "test_helper"

class RagEval::DatasetTest < ActiveSupport::TestCase
  test "loads all lectures from the evaluation dataset" do
    lectures = RagEval::Dataset.load
    assert_equal 3, lectures.size
  end

  test "each lecture has an id, content, and questions" do
    lectures = RagEval::Dataset.load
    lectures.each do |lecture|
      assert lecture.id.present?, "Lecture missing id"
      assert lecture.content.present?, "Lecture #{lecture.id} missing content"
      assert lecture.questions.any?, "Lecture #{lecture.id} has no questions"
    end
  end

  test "algorithms lecture has correct question count" do
    lecture = RagEval::Dataset.load_lecture("algorithms")
    assert_not_nil lecture
    assert_equal 7, lecture.questions.size
  end

  test "machine_learning lecture has correct question count" do
    lecture = RagEval::Dataset.load_lecture("machine_learning")
    assert_not_nil lecture
    assert_equal 7, lecture.questions.size
  end

  test "operating_systems lecture has correct question count" do
    lecture = RagEval::Dataset.load_lecture("operating_systems")
    assert_not_nil lecture
    assert_equal 7, lecture.questions.size
  end

  test "each question has expected_answer and expected_keywords" do
    lectures = RagEval::Dataset.load
    lectures.each do |lecture|
      lecture.questions.each do |q|
        assert q.question.present?, "Question text missing in #{lecture.id}"
        assert q.expected_answer.present?, "Expected answer missing for: #{q.question}"
        assert q.expected_keywords.is_a?(Array), "Expected keywords should be an array for: #{q.question}"
        assert q.expected_keywords.any?, "Expected keywords should not be empty for: #{q.question}"
      end
    end
  end

  test "lecture content contains relevant material" do
    algorithms = RagEval::Dataset.load_lecture("algorithms")
    assert_includes algorithms.content, "bubble sort"
    assert_includes algorithms.content.downcase, "merge sort"
    assert_includes algorithms.content.downcase, "quick sort"

    ml = RagEval::Dataset.load_lecture("machine_learning")
    assert_includes ml.content.downcase, "gradient descent"
    assert_includes ml.content.downcase, "supervised"

    os = RagEval::Dataset.load_lecture("operating_systems")
    assert_includes os.content.downcase, "process"
    assert_includes os.content.downcase, "virtual memory"
  end

  test "load_lecture returns nil for unknown lecture" do
    assert_nil RagEval::Dataset.load_lecture("nonexistent")
  end
end
