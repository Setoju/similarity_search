module Reranking
  # LLM-based listwise reranker.
  #
  # Sends a single prompt to Google Gemini containing the query and all
  # candidate passages. Gemini returns a relevance score (0–10) for each
  # passage in one round-trip.  Results below the threshold are discarded;
  # the remainder are returned sorted by descending relevance score, with a
  # :rerank_score key added to each result hash.
  #
  # Usage:
  #   reranked = Reranking::LlmReranker.new(query, candidates, threshold: 5).call
  #   # candidates must be an Array<Hash> with at least a :content key
  #
  # On any error the original order is preserved and all passages are kept
  # (scores default to 10), so retrieval always degrades gracefully.
  class LlmReranker
    DEFAULT_THRESHOLD = 5

    def initialize(query, results, threshold: DEFAULT_THRESHOLD)
      @query = query
      @results = results
      @threshold = threshold.clamp(0, 10)
    end

    def call
      return [] if @results.empty?

      scored = score_results

      scored
        .select { |r| r[:rerank_score] >= @threshold }
        .sort_by { |r| -r[:rerank_score] }
    end

    private

    def score_results
      prompt = build_prompt
      response = Embeddings::GoogleGeminiClient.new.generate(prompt)
      apply_scores(parse_scores(response))
    rescue => e
      Rails.logger.warn "[Reranking::LlmReranker] Reranking failed, using fallback: #{e.message}"
      apply_scores(fallback_scores)
    end

    def apply_scores(scores)
      @results.each_with_index.map do |result, idx|
        result.merge(rerank_score: scores[idx] || 10)
      end
    end

    def build_prompt
      passages = @results.each_with_index.map do |r, i|
        "[#{i}] #{r[:content]}"
      end.join("\n\n")

      <<~PROMPT
        You are a relevance-scoring assistant.

        Given the user query and the numbered passages below, score each passage
        for how directly and completely it answers the query.

        Scoring scale:
          0-3  : Off-topic or not helpful
          4-6  : Partially relevant but incomplete
          7-10 : Highly relevant and directly useful

        User query: #{@query}

        Passages:
        #{passages}

        Rules:
        - Return ONLY a JSON array of integers, one score per passage, in the
          same order as the passages above.
        - Do NOT include any explanation, markdown, or extra text.
        - Example for 3 passages: [8, 2, 6]
      PROMPT
    end

    def parse_scores(response)
      match = response.to_s.match(/\[\s*\d[\d\s,]*\]/)
      return fallback_scores unless match

      scores = JSON.parse(match[0])
      return fallback_scores unless scores.is_a?(Array) && scores.size == @results.size

      scores.map { |s| s.to_i.clamp(0, 10) }
    rescue JSON::ParserError
      fallback_scores
    end

    def fallback_scores
      Array.new(@results.size, 10)
    end
  end
end
