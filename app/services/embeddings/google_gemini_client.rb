require "faraday"
require "json"

module Embeddings
  class GoogleGeminiClient
    BASE_URL = "https://generativelanguage.googleapis.com"
    MODEL = "gemma-3-1b-it"

    def initialize
      api_key = ENV.fetch("GOOGLE_API_KEY") { raise "GOOGLE_API_KEY environment variable is not set" }

      @conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.adapter Faraday.default_adapter
        f.params["key"] = api_key
        f.response :raise_error
      end
    end

    def generate(prompt)
      response = @conn.post("/v1beta/models/#{MODEL}:generateContent") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          contents: [
            {
              parts: [
                { text: prompt }
              ]
            }
          ]
        }.to_json
      end

      parse_response(response)
    rescue Faraday::TimeoutError
      raise "Google Gemini request timed out."
    rescue Faraday::ConnectionFailed
      raise "Cannot connect to Google Gemini API."
    end

    private

    def parse_response(response)
      parsed = JSON.parse(response.body)

      if parsed["error"]
        raise "Google Gemini API error: #{parsed['error']['message']}"
      end

      candidates = parsed.dig("candidates")
      raise "No candidates returned by Google Gemini API" if candidates.nil? || candidates.empty?

      candidates.first.dig("content", "parts", 0, "text") || raise("Unexpected response format from Google Gemini: #{parsed}")
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Google Gemini: #{e.message}"
    end
  end
end
