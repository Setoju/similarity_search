require "test_helper"

class Similarity::ResolverTest < ActiveSupport::TestCase
  test "returns Cosine strategy for 'cosine'" do
    assert_equal Similarity::Cosine, Similarity::Resolver.call("cosine")
  end

  test "returns Euclidean strategy for 'euclidean'" do
    assert_equal Similarity::Euclidean, Similarity::Resolver.call("euclidean")
  end

  test "defaults to Cosine when no argument is passed" do
    assert_equal Similarity::Cosine, Similarity::Resolver.call
  end

  test "defaults to Cosine for an unknown strategy name" do
    assert_equal Similarity::Cosine, Similarity::Resolver.call("unknown")
    assert_equal Similarity::Cosine, Similarity::Resolver.call("manhattan")
  end

  test "returns Cosine for nil input" do
    assert_equal Similarity::Cosine, Similarity::Resolver.call(nil)
  end

  test "accepts symbol input" do
    assert_equal Similarity::Cosine,    Similarity::Resolver.call(:cosine)
    assert_equal Similarity::Euclidean, Similarity::Resolver.call(:euclidean)
  end

  test "returned strategy responds to call" do
    [ "cosine", "euclidean" ].each do |type|
      strategy = Similarity::Resolver.call(type)
      assert strategy.respond_to?(:call), "#{strategy} should respond to :call"
    end
  end
end
