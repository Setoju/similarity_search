module RagEval
  class Evaluator
    Result = Struct.new(
      :lecture_id, :question, :expected_answer, :rag_answer, :sources,
      :keyword_recall, :token_f1, :factual_overlap, :retrieval_precision,
      :retrieval_hit, :overall_score, :passed,
      keyword_init: true
    )

    Summary = Struct.new(
      :total_questions, :passed, :failed,
      :avg_keyword_recall, :avg_token_f1, :avg_factual_overlap,
      :avg_retrieval_precision, :retrieval_hit_rate, :avg_overall_score,
      :results,
      keyword_init: true
    )

    PASS_THRESHOLD = 30.0

    def initialize(search_type: "cosine", rerank: false, pass_threshold: PASS_THRESHOLD)
      @search_type = search_type
      @rerank = rerank
      @pass_threshold = pass_threshold
    end

    # Evaluate all lectures and questions
    def evaluate_all
      lectures = RagEval::Dataset.load
      results = lectures.flat_map { |lecture| evaluate_lecture(lecture) }
      build_summary(results)
    end

    # Evaluate a single lecture
    def evaluate_lecture(lecture)
      lecture.questions.map do |q|
        evaluate_question(lecture.id, q)
      end
    end

    # Evaluate a single question
    def evaluate_question(lecture_id, question)
      rag_result = Rag::Query.new(
        question.question,
        search_type: @search_type,
        rerank: @rerank
      ).call

      answer = rag_result[:answer]
      sources = rag_result[:sources]
      sources_array = sources.is_a?(Array) ? sources : []

      kw_recall = Metrics.keyword_recall(answer, question.expected_keywords)
      f1 = Metrics.token_f1(answer, question.expected_answer)
      fo = Metrics.factual_overlap(answer, question.expected_answer)
      rp = Metrics.retrieval_precision(sources_array, question.expected_keywords)
      rh = Metrics.retrieval_hit?(sources_array, question.expected_keywords)
      overall = Metrics.overall_score(
        answer: answer,
        expected_answer: question.expected_answer,
        expected_keywords: question.expected_keywords,
        sources: sources_array
      )

      Result.new(
        lecture_id: lecture_id,
        question: question.question,
        expected_answer: question.expected_answer,
        rag_answer: answer,
        sources: sources_array,
        keyword_recall: kw_recall,
        token_f1: f1,
        factual_overlap: fo,
        retrieval_precision: rp,
        retrieval_hit: rh,
        overall_score: overall,
        passed: overall >= @pass_threshold
      )
    end

    private

    def build_summary(results)
      total = results.size
      passed = results.count(&:passed)

      Summary.new(
        total_questions: total,
        passed: passed,
        failed: total - passed,
        avg_keyword_recall: avg(results.map(&:keyword_recall)),
        avg_token_f1: avg(results.map(&:token_f1)),
        avg_factual_overlap: avg(results.map(&:factual_overlap)),
        avg_retrieval_precision: avg(results.map(&:retrieval_precision)),
        retrieval_hit_rate: total.positive? ? (results.count(&:retrieval_hit).to_f / total).round(3) : 0.0,
        avg_overall_score: avg(results.map(&:overall_score)),
        results: results
      )
    end

    def avg(values)
      return 0.0 if values.empty?
      (values.sum / values.size).round(3)
    end
  end
end
