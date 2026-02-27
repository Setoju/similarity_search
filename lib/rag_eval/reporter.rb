module RagEval
  class Reporter
    def initialize(summary)
      @summary = summary
    end

    def to_s
      lines = []
      lines << "=" * 80
      lines << "RAG EVALUATION REPORT"
      lines << "=" * 80
      lines << ""
      lines << "Overall Results:"
      lines << "  Total questions:        #{@summary.total_questions}"
      lines << "  Passed:                 #{@summary.passed}"
      lines << "  Failed:                 #{@summary.failed}"
      lines << "  Pass rate:              #{pass_rate}%"
      lines << ""
      lines << "Average Metrics:"
      lines << "  Keyword recall:         #{format_pct(@summary.avg_keyword_recall)}"
      lines << "  Token F1:               #{format_pct(@summary.avg_token_f1)}"
      lines << "  Factual overlap:        #{format_pct(@summary.avg_factual_overlap)}"
      lines << "  Retrieval precision:    #{format_pct(@summary.avg_retrieval_precision)}"
      lines << "  Retrieval hit rate:     #{format_pct(@summary.retrieval_hit_rate)}"
      lines << "  Overall score:          #{@summary.avg_overall_score}/100"
      lines << ""
      lines << "-" * 80
      lines << "Detailed Results:"
      lines << "-" * 80

      @summary.results.each_with_index do |result, idx|
        lines << ""
        lines << "#{idx + 1}. [#{result.lecture_id}] #{result.question}"
        lines << "   Expected: #{truncate(result.expected_answer, 100)}"
        lines << "   RAG answer: #{truncate(result.rag_answer, 100)}"
        lines << "   Keyword recall: #{format_pct(result.keyword_recall)} | F1: #{format_pct(result.token_f1)} | Overlap: #{format_pct(result.factual_overlap)}"
        lines << "   Retrieval precision: #{format_pct(result.retrieval_precision)} | Hit: #{result.retrieval_hit ? 'YES' : 'NO'}"
        lines << "   Overall: #{result.overall_score}/100 #{result.passed ? 'PASS' : 'FAIL'}"
        lines << "   Sources: #{result.sources.is_a?(Array) ? result.sources.size : 0} chunks"
      end

      lines << ""
      lines << "=" * 80
      lines.join("\n")
    end

    private

    def pass_rate
      return 0 if @summary.total_questions.zero?
      (@summary.passed.to_f / @summary.total_questions * 100).round(1)
    end

    def format_pct(value)
      "#{(value * 100).round(1)}%"
    end

    def truncate(text, max)
      text.to_s.length > max ? "#{text[0...max]}..." : text.to_s
    end
  end
end
