require "faraday"
require "json"

module Embeddings
  class GoogleGeminiClient
    BASE_URL = "https://generativelanguage.googleapis.com"
    MODEL = "gemma-3-27b-it"
    LIGHT_MODEL = "gemma-3-1b-it"
    CACHE_MODEL = "gemini-2.0-flash-lite"

    def initialize(connection: nil)
      @conn = connection || self.class.build_connection
    end

    def self.connection
      build_connection
    end

    def self.build_connection
      api_key = ENV.fetch("GOOGLE_API_KEY") { raise "GOOGLE_API_KEY environment variable is not set" }

      Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.adapter Faraday.default_adapter
        f.params["key"] = api_key
        f.response :raise_error
      end
    end

    def generate(prompt, model: MODEL, generate_metrics: false)
      response = post_generate_content(prompt, model)

      generate_metrics ? parse_response_with_metrics(response) : parse_response(response)
    rescue Faraday::ClientError => e
      body = JSON.parse(e.response[:body]) rescue {}
      raise "Google Gemini API error: #{body.dig('error', 'message') || e.message}"
    rescue Faraday::TimeoutError
      raise "Google Gemini request timed out."
    rescue Faraday::ConnectionFailed
      raise "Cannot connect to Google Gemini API."
    end

    # Uploads +text+ as cached content so it can be referenced by many
    # subsequent generate calls without re-sending the payload each time.
    # Returns the cache resource name (e.g. "cachedContents/abc123").
    # ttl (time-to-live) is cache duration
    def create_cached_content(text, ttl: "300s")
      response = @conn.post("/v1beta/cachedContents") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: "models/#{CACHE_MODEL}",
          contents: [
            { role: "user",  parts: [{ text: text }] },
            { role: "model", parts: [{ text: "Document loaded. Ready to provide context for chunks." }] }
          ],
          ttl: ttl
        }.to_json
      end

      parsed = JSON.parse(response.body)
      parsed["name"] || raise("Failed to create cached content: #{parsed}")
    rescue Faraday::ClientError => e
      body = JSON.parse(e.response[:body]) rescue {}
      raise "Google Gemini cache error: #{body.dig('error', 'message') || e.message}"
    end

    # Generates content using a previously created cached-content resource.
    def generate_with_cache(cached_content_name, prompt)
      response = @conn.post("/v1beta/models/#{CACHE_MODEL}:generateContent") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          cachedContent: cached_content_name,
          contents: [
            { role: "user", parts: [{ text: prompt }] }
          ]
        }.to_json
      end

      parse_response(response)
    rescue Faraday::ClientError => e
      body = JSON.parse(e.response[:body]) rescue {}
      raise "Google Gemini API error: #{body.dig('error', 'message') || e.message}"
    end

    # Deletes a cached-content resource. Fails silently on errors.
    def delete_cached_content(name)
      @conn.delete("/v1beta/#{name}")
    rescue => e
      Rails.logger.warn "[GoogleGeminiClient] Failed to delete cached content '#{name}': #{e.message}"
    end

    private

    def post_generate_content(prompt, model)
      @conn.post("/v1beta/models/#{model}:generateContent") do |req|
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
    end

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

    def parse_response_with_metrics(response)
      parsed = JSON.parse(response.body)

      if parsed["error"]
        raise "Google Gemini API error: #{parsed['error']['message']}"
      end

      candidates = parsed.dig("candidates")
      raise "No candidates returned by Google Gemini API" if candidates.nil? || candidates.empty?

      content = candidates.first.dig("content", "parts", 0, "text") || raise("Unexpected response format from Google Gemini: #{parsed}")
      usage = parsed["usageMetadata"] || parsed["usage_metadata"] || {}

      output_tokens = token_value(usage, "candidatesTokenCount", "candidates_token_count", "outputTokenCount", "output_token_count")
      input_tokens = token_value(usage, "promptTokenCount", "prompt_token_count", "inputTokenCount", "input_token_count")
      total_tokens = token_value(usage, "totalTokenCount", "total_token_count")

      if input_tokens.zero? && total_tokens.positive? && output_tokens.positive?
        input_tokens = [total_tokens - output_tokens, 0].max
      end

      {
        content: content,
        input_tokens: input_tokens,
        output_tokens: output_tokens
      }
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Google Gemini: #{e.message}"
    end

    def token_value(usage, *keys)
      keys.each do |key|
        value = usage[key]
        return value.to_i if value
      end

      0
    end
  end
end
