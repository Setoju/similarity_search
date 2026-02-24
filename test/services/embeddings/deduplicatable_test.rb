require "test_helper"

class Embeddings::DeduplicatableTest < ActiveSupport::TestCase
  # Minimal host class exposing the private deduplicate helper
  class TestHost
    include Embeddings::Deduplicatable

    def run(items, &block)
      deduplicate(items, &block)
    end
  end

  setup do
    @host = TestHost.new
  end

  test "returns all items when all content is unique" do
    items = [["apple", 1.0], ["banana", 0.9], ["cherry", 0.8]]
    result = @host.run(items) { |item, _| item }
    assert_equal 3, result.length
  end

  test "keeps only the first occurrence of duplicate content" do
    items = [["hello world", 1.0], ["hello world", 0.9], ["different", 0.8]]
    result = @host.run(items) { |item, _| item }

    assert_equal 2, result.length
    assert_equal "hello world", result.first.first
    assert_in_delta 1.0, result.first.last, 0.0001
  end

  test "deduplication is case-insensitive" do
    items = [["Hello World", 1.0], ["hello world", 0.9]]
    result = @host.run(items) { |item, _| item }
    assert_equal 1, result.length
  end

  test "deduplication normalizes internal whitespace" do
    items = [["hello  world", 1.0], ["hello world", 0.9]]
    result = @host.run(items) { |item, _| item }
    assert_equal 1, result.length
  end

  test "deduplication strips leading and trailing whitespace" do
    items = [["  hello  ", 1.0], ["hello", 0.9]]
    result = @host.run(items) { |item, _| item }
    assert_equal 1, result.length
  end

  test "returns empty array for empty input" do
    assert_equal [], @host.run([]) { |item| item }
  end

  test "works with hash-style items" do
    items = [
      { content: "same text", score: 1.0 },
      { content: "same text", score: 0.8 },
      { content: "other text", score: 0.6 }
    ]
    result = @host.run(items) { |r| r[:content] }

    assert_equal 2, result.length
    assert_equal 1.0, result.first[:score]
  end

  test "preserves original item order for unique items" do
    items = [["c", 0.3], ["a", 1.0], ["b", 0.7]]
    result = @host.run(items) { |item, _| item }
    assert_equal ["c", "a", "b"], result.map(&:first)
  end
end
