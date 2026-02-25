module Embeddings
  # Retrieves the top-k most relevant chunks for a given query using
  # vector similarity (cosine by default, or euclidean).
  #
  # Chunks are the primary retrieval unit. Sentences stored inside each
  # chunk carry character offsets used for source highlighting only — they
  # are no longer embedded.
  #
  # Usage:
  #   results = Embeddings::ChunkSearch.new("my query", top: 5).call
  #   # => [{ content:, score:, document_id:, chunk_id:, start_char:, end_char: }, ...]
  class ChunkSearch
    include Deduplicatable

    def initialize(query, search_type = "cosine", top: 5, threshold: 0.4)
      @query = query
      @top = top
      @threshold = threshold
      @similarity_calculator = Similarity::Resolver.call(search_type)
    end

    def call
      client = Embeddings::OllamaClient.new
      query_vector = client.embed(Preprocessing::Normalizer.call(@query))

      chunks = Chunk.includes(:document).where.not(embedding: nil)

      scored = chunks.filter_map do |chunk|
        next unless chunk.embedding.is_a?(Array) && query_vector.is_a?(Array)

        score = @similarity_calculator.call(query_vector, chunk.embedding)
        [chunk, score]
      end

      scored
        .select { |_, score| score > @threshold }
        .sort_by { |_, score| -score }
        .then { |results| deduplicate(results) { |(chunk, _)| chunk.content } }
        .first(@top)
        .map { |chunk, score| build_result(chunk, score) }
    end

    private

    def build_result(chunk, score)
      {
        content: chunk.contextualized_content,
        score: score,
        document_id: chunk.document_id,
        chunk_id: chunk.id,
        start_char: chunk.start_char,
        end_char: chunk.end_char
      }
    end
  end
end
