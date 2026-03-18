module QueryRewriting
  class Pipeline
    def initialize(query, hyde: false, decompose: false)
      @query = query
      @hyde = hyde
      @decompose = decompose
    end

    def call
      queries = decompose_query
      apply_hyde(queries)
    end

    private

    def decompose_query
      @decompose ? Decomposer.new(@query).call : [@query]
    end

    def apply_hyde(queries)
      return queries.map { |q| { original: q, hyde_doc: nil } } unless @hyde

      # Parallelize HyDE generation for multiple subqueries
      threads = queries.map do |q|
        Thread.new { { original: q, hyde_doc: Hyde.new(q).call } }
      end
      threads.map(&:value)
    end
  end
end
