module Rag
  class Query
    def initialize(query, search_type: "cosine", top: 5, rerank: false, rerank_threshold: Reranking::LlmReranker::DEFAULT_THRESHOLD)
      @query = query
      @search_type = search_type
      @top = top
      @rerank = rerank
      @rerank_threshold = rerank_threshold
    end

    def call
      chunks = retrieve_chunks
      chunks = rerank(chunks) if @rerank && chunks.any?

      context = chunks.empty? ? "" : build_context(chunks)

      prompt = build_prompt(context)
      answer = Embeddings::GoogleGeminiClient.new.generate(prompt)

      sources = format_sources(chunks).empty? ? "Internet" : format_sources(chunks)

      {
        answer: answer,
        sources: sources
      }
    end

    private

    def retrieve_chunks
      if @search_type == "hybrid"
        Embeddings::HybridSearch.new(@query, top: @top).call
      else
        Embeddings::ChunkSearch.new(@query, @search_type, top: @top).call
      end
    end

    def rerank(chunks)
      Reranking::LlmReranker.new(@query, chunks, threshold: @rerank_threshold).call
    rescue => e
      Rails.logger.error "[Rag::Query] Reranking error: #{e.message}"
      chunks
    end

    def build_context(chunks)
      chunks.map.with_index(1) do |result, i|
        "[#{i}] #{result[:content]}"
      end.join("\n\n")
    end

    def build_prompt(context)
      if context.empty?
        <<~PROMPT
          Answer following question shortly based on your knowledge

          Question: #{@query}
        PROMPT
      else
        <<~PROMPT
          Answer the question using only the context provided below.

          Context:
          #{context}

          Question: #{@query}
        PROMPT
      end
    end

    def format_sources(chunks)
      chunks.map do |result|
        {
          content: result[:content],
          score: result[:score],
          document_id: result[:document_id],
          chunk_id: result[:chunk_id],
          start_char: result[:start_char],
          end_char: result[:end_char]
        }
      end
    end
  end
end
