require "test_helper"

class Bm25::TokenizerTest < ActiveSupport::TestCase
  test "downcases all tokens" do
    tokens = Bm25::Tokenizer.call("Hello World")
    assert_equal %w[hello world], tokens
  end

  test "splits on non-alphanumeric characters" do
    tokens = Bm25::Tokenizer.call("Ruby on Rails: fast, powerful!")
    assert_includes tokens, "ruby"
    assert_includes tokens, "rails"
    assert_includes tokens, "fast"
    assert_includes tokens, "powerful"
  end

  test "removes stop words" do
    tokens = Bm25::Tokenizer.call("the quick brown fox")
    refute_includes tokens, "the"
    assert_includes tokens, "quick"
    assert_includes tokens, "brown"
    assert_includes tokens, "fox"
  end

  test "removes tokens shorter than 2 characters" do
    tokens = Bm25::Tokenizer.call("a b two three")
    refute_includes tokens, "a"
    refute_includes tokens, "b"
    assert_includes tokens, "two"
    assert_includes tokens, "three"
  end

  test "returns empty array for empty string" do
    assert_equal [], Bm25::Tokenizer.call("")
  end

  test "handles nil gracefully" do
    assert_equal [], Bm25::Tokenizer.call(nil)
  end

  test "returns empty array when all tokens are stop words" do
    assert_equal [], Bm25::Tokenizer.call("the a an is")
  end
end
