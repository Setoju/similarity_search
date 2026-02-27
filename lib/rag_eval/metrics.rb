module RagEval
  class Metrics
    # Keyword recall: fraction of expected keywords found in the answer
    def self.keyword_recall(answer, expected_keywords)
      return 1.0 if expected_keywords.empty?

      normalized_answer = answer.to_s.downcase
      found = expected_keywords.count { |kw| normalized_answer.include?(kw.downcase) }
      found.to_f / expected_keywords.size
    end

    # Token-level F1 between answer and expected answer
    def self.token_f1(answer, expected_answer)
      answer_tokens = tokenize(answer)
      expected_tokens = tokenize(expected_answer)

      return 0.0 if answer_tokens.empty? || expected_tokens.empty?

      common = (answer_tokens & expected_tokens).size.to_f

      precision = common / answer_tokens.size
      recall = common / expected_tokens.size

      return 0.0 if (precision + recall).zero?

      2.0 * precision * recall / (precision + recall)
    end

    # Check if answer contains the essential facts from the expected answer
    def self.factual_overlap(answer, expected_answer)
      answer_tokens = tokenize(answer).to_set
      expected_tokens = tokenize(expected_answer).to_set

      return 0.0 if expected_tokens.empty?

      overlap = (answer_tokens & expected_tokens).size.to_f
      overlap / expected_tokens.size
    end

    # Retrieval precision: how many retrieved chunks are relevant (contain topic keywords)
    def self.retrieval_precision(sources, expected_keywords)
      return 0.0 if sources.nil? || !sources.is_a?(Array) || sources.empty?

      relevant = sources.count do |source|
        content = source[:content].to_s.downcase
        expected_keywords.any? { |kw| content.include?(kw.downcase) }
      end

      relevant.to_f / sources.size
    end

    # Retrieval hit: at least one retrieved chunk contains a relevant keyword
    def self.retrieval_hit?(sources, expected_keywords)
      return false if sources.nil? || !sources.is_a?(Array) || sources.empty?

      sources.any? do |source|
        content = source[:content].to_s.downcase
        expected_keywords.any? { |kw| content.include?(kw.downcase) }
      end
    end

    # Combined score (0-100) for an answer
    def self.overall_score(answer:, expected_answer:, expected_keywords:, sources: nil)
      kw = keyword_recall(answer, expected_keywords)
      f1 = token_f1(answer, expected_answer)
      fo = factual_overlap(answer, expected_answer)

      # Weighted combination
      score = (kw * 40 + f1 * 30 + fo * 30)

      # Bonus for retrieval quality
      if sources.is_a?(Array) && sources.any?
        rp = retrieval_precision(sources, expected_keywords)
        score = score * 0.8 + rp * 20
      end

      score.round(1)
    end

    private_class_method def self.tokenize(text)
      text.to_s
          .downcase
          .gsub(/[^a-z0-9\s]/, " ")
          .split
          .reject { |t| t.length < 2 }
    end
  end
end
