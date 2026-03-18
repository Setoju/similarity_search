module QueryRewriting
  class Hyde
    def initialize(query)
      @query = query
    end

    def call
      prompt = build_prompt
      Embeddings::GoogleGeminiClient.new.generate(prompt)
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
