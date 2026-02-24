require "test_helper"

class Bm25::IndexTest < ActiveSupport::TestCase
  setup do
    @corpus = [
      { id: 1, text: "Ruby on Rails is a web framework" },
      { id: 2, text: "Python is a general purpose programming language" },
      { id: 3, text: "Rails makes building web applications fast and enjoyable" }
    ]
    @index = Bm25::Index.new(@corpus)
  end

  test "returns size equal to corpus length" do
    assert_equal 3, @index.size
  end

  test "returns results sorted by descending score" do
    results = @index.score("Rails web framework")
    scores  = results.map { |r| r[:score] }
    assert_equal scores, scores.sort.reverse
  end

  test "ranks most relevant document highest for specific query" do
    results = @index.score("Rails web framework")
    # First and third docs contain "rails" and/or "web" — they should outscore doc 2
    top_ids = results.first(2).map { |r| r[:id] }
    assert_includes top_ids, 1
  end

  test "returns empty array for empty query" do
    assert_equal [], @index.score("")
  end

  test "returns empty array for stop-word-only query" do
    assert_equal [], @index.score("the a and is")
  end

  test "respects top parameter" do
    results = @index.score("Rails web framework", top: 2)
    assert_equal 2, results.length
  end

  test "top: nil returns all documents that have a positive score" do
    results = @index.score("Ruby Rails Python", top: nil)
    assert results.size >= 1
  end

  test "each result has :id and :score keys" do
    results = @index.score("Rails")
    results.each do |r|
      assert r.key?(:id),    "Missing :id key"
      assert r.key?(:score), "Missing :score key"
    end
  end

  test "result ids correspond to corpus ids" do
    corpus_ids = @corpus.map { |c| c[:id] }
    results    = @index.score("Rails")
    results.each do |r|
      assert_includes corpus_ids, r[:id]
    end
  end

  test "document without matching term gets zero score" do
    index   = Bm25::Index.new([{ id: 99, text: "something completely unrelated" }])
    results = index.score("Ruby Rails", top: nil)
    assert_equal 0, results.size, "Expected no results for a query that matches no terms"
  end

  test "empty corpus returns empty results" do
    index = Bm25::Index.new([])
    assert_equal [], index.score("Rails")
  end
end
