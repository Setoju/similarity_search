module QueryRewriting
  class Hyde
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
        response[:content]
      else
        @gemini_client.generate(prompt, model: Embeddings::GoogleGeminiClient::LIGHT_MODEL)
      end
    end

    private

    def build_prompt
      <<~PROMPT
        Write a short passage (2-3 sentences) that directly answers this question.
        Do not include phrases like "Based on..." or "According to...".
        Just write the factual answer as if it were from a document.

        Question: #{@query}

        Passage:
      PROMPT
    end
  end
end
