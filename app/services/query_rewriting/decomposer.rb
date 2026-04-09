module QueryRewriting
  class Decomposer
    attr_reader :token_usage

    def initialize(query, gemini_client: Embeddings::GoogleGeminiClient.new, track_metrics: false)
      @query = query
      @gemini_client = gemini_client
      @track_metrics = track_metrics
      @token_usage = { input_tokens: 0, output_tokens: 0 }
    end

    def call
      prompt = build_prompt
      if @track_metrics
        response = @gemini_client.generate(
          prompt,
          model: Embeddings::GoogleGeminiClient::LIGHT_MODEL,
          generate_metrics: true
        )
        @token_usage[:input_tokens] += response[:input_tokens].to_i
        @token_usage[:output_tokens] += response[:output_tokens].to_i
        parse_response(response[:content])
      else
        response = @gemini_client.generate(prompt, model: Embeddings::GoogleGeminiClient::LIGHT_MODEL)
        parse_response(response)
      end
    end

    private

    def build_prompt
      <<~PROMPT
        Analyze this query. If it contains multiple distinct questions or asks about
        multiple aspects, split it into simpler subqueries. If it's already simple,
        return it unchanged.

        Output format: One query per line. No numbering, no bullets.

        Query: #{@query}

        Subqueries:
      PROMPT
    end

    def parse_response(response)
      subqueries = response
        .strip
        .split("\n")
        .map { |line| line.gsub(/^\d+[\.\)]\s*/, "").strip }
        .reject(&:empty?)

      subqueries.empty? ? [@query] : subqueries
    end
  end
end
