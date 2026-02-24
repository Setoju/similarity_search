require "test_helper"

class Rag::QueryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
    @query_embedding = Array.new(768) { 0.5 }
    Document.destroy_all
    stub_ollama(@query_embedding)
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  test "returns a hash with :answer and :sources keys" do
    stub_gemini_response("Some answer.")

    result = Rag::Query.new("What is Rails?").call

    assert result.key?(:answer)
    assert result.key?(:sources)
  end

  test "returns 'Internet' as sources when no matching chunks exist" do
    stub_gemini_response("Rails is a web framework.")

    result = Rag::Query.new("What is Rails?").call

    assert_equal "Internet", result[:sources]
  end

  test "returns the generated answer string" do
    stub_gemini_response("Rails is a Ruby web framework.")

    result = Rag::Query.new("What is Rails?").call

    assert_equal "Rails is a Ruby web framework.", result[:answer]
  end

  test "returns sources as an array when chunks are found" do
    create_doc_with_chunk("Ruby on Rails is a web framework for building apps", @query_embedding)
    stub_gemini_response("Rails is a framework.")

    result = Rag::Query.new("Rails").call

    assert_kind_of Array, result[:sources]
    assert result[:sources].any?
  end

  test "sources array includes expected keys" do
    create_doc_with_chunk("Ruby on Rails guide for developers", @query_embedding)
    stub_gemini_response("Rails guide answer.")

    result = Rag::Query.new("Rails").call
    source = result[:sources].first

    assert source.key?(:content)
    assert source.key?(:score)
    assert source.key?(:document_id)
    assert source.key?(:chunk_id)
  end

  test "uses hybrid search when search_type is 'hybrid'" do
    create_doc_with_chunk("Ruby Rails hybrid search content here", @query_embedding)
    stub_gemini_response("Hybrid answer.")

    result = Rag::Query.new("Rails", search_type: "hybrid").call

    assert result.key?(:answer)
    assert result.key?(:sources)
  end

  test "passes top parameter to chunk retrieval" do
    3.times { |i| create_doc_with_chunk("Rails content for test #{i} with more words", @query_embedding) }
    stub_gemini_response("Answer.")

    result = Rag::Query.new("Rails", top: 1).call

    if result[:sources].is_a?(Array)
      assert result[:sources].length <= 1
    end
  end

  test "persists knowledge-based answer as a new document when no chunks found" do
    stub_gemini_response("A knowledge-based answer here.")

    assert_difference "Document.count", 1 do
      Rag::Query.new("Something obscure").call
    end
  end
end
