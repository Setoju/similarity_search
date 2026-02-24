require "test_helper"

class Similarity::EuclideanTest < ActiveSupport::TestCase
  test "returns 1.0 for identical vectors" do
    vec = [1.0, 2.0, 3.0]
    assert_in_delta 1.0, Similarity::Euclidean.call(vec, vec), 0.0001
  end

  test "returns lower score for very distant vectors" do
    vec_a = [0.0, 0.0]
    vec_b = [100.0, 100.0]
    assert Similarity::Euclidean.call(vec_a, vec_b) < 0.1
  end

  test "score decreases as distance increases" do
    origin = [0.0, 0.0]
    near   = [1.0, 0.0]
    far    = [10.0, 0.0]
    assert Similarity::Euclidean.call(origin, near) > Similarity::Euclidean.call(origin, far)
  end

  test "score is always positive" do
    vec_a = [1.0, -2.0, 3.0]
    vec_b = [-1.0, 2.0, -3.0]
    assert Similarity::Euclidean.call(vec_a, vec_b) > 0.0
  end

  test "score is bounded between 0 and 1" do
    vec_a = [1.0, 0.0, 0.0]
    vec_b = [0.0, 1.0, 0.0]
    result = Similarity::Euclidean.call(vec_a, vec_b)
    assert result >= 0.0 && result <= 1.0
  end

  test "returns 0.0 for empty vectors" do
    assert_equal 0.0, Similarity::Euclidean.call([], [])
    assert_equal 0.0, Similarity::Euclidean.call([1.0], [])
    assert_equal 0.0, Similarity::Euclidean.call([], [1.0])
  end

  test "returns 0.0 for mismatched dimensions" do
    assert_equal 0.0, Similarity::Euclidean.call([1.0, 2.0], [1.0])
  end

  test "returns 0.0 for non-array inputs" do
    assert_equal 0.0, Similarity::Euclidean.call(nil, nil)
    assert_equal 0.0, Similarity::Euclidean.call("str", [1.0])
    assert_equal 0.0, Similarity::Euclidean.call([1.0], nil)
  end

  test "is commutative" do
    vec_a = [1.0, 2.0, 3.0]
    vec_b = [4.0, 5.0, 6.0]
    assert_in_delta Similarity::Euclidean.call(vec_a, vec_b),
                    Similarity::Euclidean.call(vec_b, vec_a),
                    0.0001
  end
end
