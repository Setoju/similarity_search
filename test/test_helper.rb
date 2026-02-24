ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

GEMINI_URL = /generativelanguage\.googleapis\.com\/v1beta\/models\/gemma-3-1b-it:generateContent/

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Stubs the Ollama embeddings endpoint to return the given vector.
    def stub_ollama(embedding = Array.new(768) { 0.5 })
      stub_request(:post, "http://localhost:11434/api/embeddings")
        .to_return(
          status: 200,
          body: { embedding: embedding }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    # Stubs the Google Gemini generateContent endpoint to return the given text.
    def stub_gemini_response(text)
      body = { candidates: [{ content: { parts: [{ text: text }] } }] }.to_json
      stub_request(:post, GEMINI_URL)
        .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
    end

    # Creates a Document with a single Chunk spanning the full content.
    def create_doc_with_chunk(content, embedding)
      doc = Document.create!(content: content)
      doc.update_column(:embedding, embedding)
      doc.chunks.create!(start_char: 0, end_char: content.length, embedding: embedding)
      doc
    end
  end
end
