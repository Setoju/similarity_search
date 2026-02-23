module Rag
  class Query
    def initialize(query, search_type: "cosine", top: 5)
      @query = query
      @search_type = search_type
      @top = top
    end

    def call
      sentences = retrieve_sentences
      knowledge_based = sentences.empty?

      context = knowledge_based ? "" : build_context(sentences)

      prompt  = build_prompt(context)
      answer  = Embeddings::GoogleGeminiClient.new.generate(prompt)

      persist_knowledge(answer) if knowledge_based

      sources = format_sources(sentences).empty? ? "Internet" : format_sources(sentences)

      {
        answer: answer,
        sources: sources
      }
    end

    private

    def retrieve_sentences
      Embeddings::SentenceSearch.new(@query, @search_type, top: @top).call
    end

    def build_context(sentences)
      sentences.map.with_index(1) do |result, i|
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

    def format_sources(sentences)
      sentences.map do |result|
        {
          content:     result[:content],
          score:       result[:score],
          document_id: result[:document_id],
          chunk_id:    result[:chunk_id],
          start_char:  result[:start_char],
          end_char:    result[:end_char]
        }
      end
    end

    def persist_knowledge(answer)
      key = knowledge_cache_key
      return if Rails.cache.exist?(key) || Document.exists?(content: answer)

      Rails.cache.write(key, true, expires_in: 1.hour)
      Document.create!(content: answer)
    rescue => e
      Rails.logger.error "Failed to persist knowledge-based answer: #{e.message}"
    end

    def knowledge_cache_key
      normalized = Preprocessing::Normalizer.call(@query)
      "rag_knowledge:#{Digest::SHA256.hexdigest(normalized)}"
    end
  end
end
