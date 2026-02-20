module Rag
  class Query
    def initialize(query, search_type: "cosine", top: 5)
      @query = query
      @search_type = search_type
      @top = top
    end

    def call
      sentences = retrieve_sentences
      raise "No relevant content found in the database." if sentences.empty?

      context = build_context(sentences)
      prompt  = build_prompt(context)
      answer  = Embeddings::GoogleGeminiClient.new.generate(prompt)

      {
        answer: answer,
        sources: format_sources(sentences)
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
      <<~PROMPT
        Answer the question using the following context:

        #{context}

        Question: #{@query}
      PROMPT
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
  end
end
