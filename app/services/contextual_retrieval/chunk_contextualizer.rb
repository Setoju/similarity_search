require "faraday"
require "json"

module ContextualRetrieval
  # Generates short contextual descriptions for document chunks using
  # Ollama's local generation API.
  #
  # Each chunk receives a succinct 1-2 sentence context that situates it
  # within the source document, which is later prepended to improve
  # embedding and search quality.
  class ChunkContextualizer
    BASE_URL = "http://localhost:11434"
    MODEL = "gemma3:1b"

    def initialize(document_content, chunks)
      @document_content = document_content
      @chunks = chunks
      @conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.adapter Faraday.default_adapter
        f.response :raise_error
      end
    end

    def self.call(document_content, chunks)
      new(document_content, chunks).call
    end

    def call
      return @chunks if @chunks.empty?

      contextualize_with_ollama
    end

    private

    def contextualize_with_ollama
      @chunks.map do |chunk|
        context = generate_context(prompt_for(chunk[:content]))
        chunk.merge(context: context.strip)
      rescue => e
        Rails.logger.warn "[ChunkContextualizer] Skipping context for chunk: #{e.message}"
        chunk.merge(context: "")
      end
    end

    def generate_context(prompt)
      response = @conn.post("/api/generate") do |req|
        req.body = {
          model: MODEL,
          prompt: prompt,
          stream: false,
          temperature: 0.2,
          num_predict: 120,
          keep_alive: 600
        }.to_json
        req.headers["Content-Type"] = "application/json"
      end

      parse_response(response)
    rescue Faraday::ClientError => e
      body = JSON.parse(e.response[:body]) rescue {}
      raise "Ollama error: #{body['error'] || e.message}"
    rescue Faraday::TimeoutError
      raise "Ollama request timed out. Model might be loading - try again in a moment."
    rescue Faraday::ConnectionFailed
      raise "Cannot connect to Ollama. Make sure it's running: ollama serve"
    end

    def parse_response(response)
      parsed = JSON.parse(response.body)

      if parsed["response"].is_a?(String)
        parsed["response"]
      elsif parsed["error"]
        raise "Ollama error: #{parsed['error']}"
      else
        raise "Unexpected response format from Ollama: #{parsed}"
      end
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Ollama: #{e.message}"
    end

    def prompt_for(chunk_content)
      <<~PROMPT.strip
        You generate contextual labels for retrieval systems.
        Write a concise 1-2 sentence context describing how the chunk fits in the full document.
        Return only the context text.

        <document>
        #{@document_content}
        </document>

        Here is the target chunk:

        <chunk>
        #{chunk_content}
        </chunk>

        Context:
      PROMPT
    end
  end
end
