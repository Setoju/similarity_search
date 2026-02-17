require "test_helper"

class Similarity::CosineTest < ActiveSupport::TestCase
  test "returns 1.0 for identical vectors" do
    vec = [1.0, 2.0, 3.0]
    assert_in_delta 1.0, Similarity::Cosine.call(vec, vec), 0.0001
  end

  test "returns -1.0 for opposite vectors" do
    vec_a = [1.0, 0.0, 0.0]
    vec_b = [-1.0, 0.0, 0.0]
    assert_in_delta(-1.0, Similarity::Cosine.call(vec_a, vec_b), 0.0001)
  end

  test "returns 0.0 for orthogonal vectors" do
    vec_a = [1.0, 0.0]
    vec_b = [0.0, 1.0]
    assert_in_delta 0.0, Similarity::Cosine.call(vec_a, vec_b), 0.0001
  end

  test "returns 0.0 for empty vectors" do
    assert_equal 0.0, Similarity::Cosine.call([], [])
    assert_equal 0.0, Similarity::Cosine.call([1.0], [])
    assert_equal 0.0, Similarity::Cosine.call([], [1.0])
  end

  test "returns 0.0 for mismatched dimensions" do
    vec_a = [1.0, 2.0]
    vec_b = [1.0, 2.0, 3.0]
    assert_equal 0.0, Similarity::Cosine.call(vec_a, vec_b)
  end

  test "returns 0.0 for non-array inputs" do
    assert_equal 0.0, Similarity::Cosine.call(nil, nil)
    assert_equal 0.0, Similarity::Cosine.call("string", [1.0])
  end

  test "returns 0.0 for zero vectors" do
    vec_a = [0.0, 0.0, 0.0]
    vec_b = [1.0, 2.0, 3.0]
    assert_equal 0.0, Similarity::Cosine.call(vec_a, vec_b)
  end

  test "clamps result to valid range" do
    vec_a = [1.0, 2.0, 3.0]
    vec_b = [4.0, 5.0, 6.0]
    result = Similarity::Cosine.call(vec_a, vec_b)
    assert result >= -1.0 && result <= 1.0
  end
end
