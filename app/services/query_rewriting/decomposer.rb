module QueryRewriting
  class Decomposer
    def initialize(query)
      @query = query
    end

    def call
      prompt = build_prompt
      response = Embeddings::GoogleGeminiClient.new.generate(prompt)
      parse_response(response)
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
