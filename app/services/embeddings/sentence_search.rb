module Embeddings
  class SentenceSearch
    def initialize(query, search_type = 'cosine', top: 5)
      @query = query
      @top = top
      @similarity_calculator = Similarity::Resolver.call(search_type)
    end

    def call
      client = Embeddings::OllamaClient.new
      query_vector = client.embed(Preprocessing::Normalizer.call(@query))

      best_document = find_best_document(query_vector)
      return [] unless best_document

      best_chunk = find_best_chunk(best_document, query_vector)
      return [] unless best_chunk

      find_best_sentences(best_chunk, query_vector)
    end

    private

    def find_best_document(query_vector)
      documents = Document.where.not(embedding: nil)

      scored = documents.filter_map do |doc|
        next unless doc.embedding&.is_a?(Array) && query_vector&.is_a?(Array)
        score = @similarity_calculator.call(query_vector, doc.embedding)
        [doc, score]
      end

      scored.max_by { |_, score| score }&.first
    end

    def find_best_chunk(document, query_vector)
      chunks = document.chunks.where.not(embedding: nil)

      scored = chunks.filter_map do |chunk|
        next unless chunk.embedding&.is_a?(Array) && query_vector&.is_a?(Array)
        score = @similarity_calculator.call(query_vector, chunk.embedding)
        [chunk, score]
      end

      scored.max_by { |_, score| score }&.first
    end

    def find_best_sentences(chunk, query_vector)
      sentences = chunk.sentences.includes(:document).where.not(embedding: nil)

      scored = sentences.filter_map do |sentence|
        next unless sentence.embedding&.is_a?(Array) && query_vector&.is_a?(Array)
        score = @similarity_calculator.call(query_vector, sentence.embedding)
        [sentence, score]
      end

      scored.sort_by { |_, score| -score }.first(@top).map do |sentence, score|
        {
          sentence: sentence,
          content: sentence.content,
          score: score,
          document_id: sentence.document_id,
          chunk_id: sentence.chunk_id,
          start_char: sentence.start_char,
          end_char: sentence.end_char
        }
      end
    end
  end
end
