require "faraday"
require "json"

module Embeddings
  class OllamaClient
    BASE_URL = "http://localhost:11434"
    EMBEDDING_MODEL = "nomic-embed-text"

    def initialize
      @conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.adapter Faraday.default_adapter
      end
    end

    def embed(text)
      embedding = make_request(text)
    end

    private

    def make_request(text)
      response = @conn.post("/api/embeddings") do |req|
        req.body = { model: EMBEDDING_MODEL, prompt: text }.to_json
        req.headers["Content-Type"] = "application/json"
      end

      parse_response(response)
    rescue Faraday::TimeoutError
      raise "Ollama request timed out. Model might be loading - try again in a moment."
    rescue Faraday::ConnectionFailed
      raise "Cannot connect to Ollama. Make sure it's running: ollama serve"
    end

    def parse_response(response)
      parsed = JSON.parse(response.body)

      if parsed["embedding"].is_a?(Array) && parsed["embedding"].any?
        parsed["embedding"]
      elsif parsed["error"]
        raise "Ollama error: #{parsed['error']}"
      else
        raise "Unexpected response format from Ollama: #{parsed}"
      end
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Ollama: #{e.message}"
    end
  end
end
