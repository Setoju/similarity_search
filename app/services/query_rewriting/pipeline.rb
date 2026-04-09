module QueryRewriting
  class Pipeline
    attr_reader :token_usage

    def initialize(query, hyde: false, decompose: false, gemini_client: Embeddings::GoogleGeminiClient.new, track_metrics: false)
      @query = query
      @hyde = hyde
      @decompose = decompose
      @gemini_client = gemini_client
      @track_metrics = track_metrics
      @token_usage = { input_tokens: 0, output_tokens: 0 }
    end

    def call
      queries = decompose_query
      apply_hyde(queries)
    end

    private

    def decompose_query
      return [@query] unless @decompose

      decomposer = Decomposer.new(@query, gemini_client: @gemini_client, track_metrics: @track_metrics)
      queries = decomposer.call
      add_token_usage(decomposer.token_usage)
      queries
    end

    def apply_hyde(queries)
      return queries.map { |q| { original: q, hyde_doc: nil } } unless @hyde

      # Parallelize HyDE generation for multiple subqueries
      threads = queries.map do |q|
        Thread.new do
          hyde = Hyde.new(q, gemini_client: @gemini_client, track_metrics: @track_metrics)
          {
            original: q,
            hyde_doc: hyde.call,
            token_usage: hyde.token_usage
          }
        end
      end

      threads.map(&:value).map do |entry|
        add_token_usage(entry[:token_usage])
        { original: entry[:original], hyde_doc: entry[:hyde_doc] }
      end
    end

    def add_token_usage(usage)
      return unless usage

      @token_usage[:input_tokens] += usage[:input_tokens].to_i
      @token_usage[:output_tokens] += usage[:output_tokens].to_i
    end
  end
end
