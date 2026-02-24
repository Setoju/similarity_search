module Embeddings
  # Hybrid chunk search: combines semantic (cosine) similarity with BM25
  # lexical relevance using a weighted linear combination, then returns the
  # top-k results above a minimum score threshold.
  #
  # Chunks are the primary retrieval unit. Sentences inside each chunk carry
  # character offsets for source highlighting only — they are not embedded.
  #
  # Scoring formula:
  #   hybrid_score = alpha * norm_semantic + (1 - alpha) * norm_bm25
  #
  # Both scores are min-max normalised to [0, 1] before combining.
  #
  # Usage:
  #   results = Embeddings::HybridSearch.new(query, top: 5).call
  #   # => [{ content:, score:, document_id:, chunk_id:, start_char:, end_char: }, ...]
  class HybridSearch
    include Deduplicatable

    # Weight given to the semantic score (0.0 – 1.0).
    # 1.0 = pure semantic; 0.0 = pure BM25.
    DEFAULT_ALPHA = 0.7

    def initialize(query, top: 5, threshold: 0.0, alpha: DEFAULT_ALPHA)
      @query = query
      @top = top
      @threshold = threshold
      @alpha = alpha.clamp(0.0, 1.0)
    end

    def call
      chunks = Chunk.includes(:document).where.not(embedding: nil).to_a
      return [] if chunks.empty?

      query_vector = embed_query
      return [] unless query_vector

      semantic = compute_semantic_scores(chunks, query_vector)
      bm25 = compute_bm25_scores(chunks)
      combined = combine_scores(chunks, semantic, bm25)

      combined
        .select { |r| r[:score] > @threshold }
        .sort_by { |r| -r[:score] }
        .then { |results| deduplicate(results) { |r| r[:chunk].content } }
        .first(@top)
        .map { |r| build_result(r) }
    end

    private

    def embed_query
      Embeddings::OllamaClient.new.embed(Preprocessing::Normalizer.call(@query))
    rescue => e
      Rails.logger.error "[HybridSearch] Failed to embed query: #{e.message}"
      nil
    end

    def compute_semantic_scores(chunks, query_vector)
      chunks.map do |chunk|
        if chunk.embedding.is_a?(Array) && query_vector.is_a?(Array)
          Similarity::Cosine.call(query_vector, chunk.embedding)
        else
          0.0
        end
      end
    end

    def compute_bm25_scores(chunks)
      corpus = chunks.each_with_index.map do |chunk, idx|
        { id: idx, text: chunk.content }
      end

      index = Bm25::Index.new(corpus)
      ranked = index.score(@query)

      scores = Array.new(chunks.size, 0.0)
      ranked.each { |r| scores[r[:id]] = r[:score] }
      scores
    end

    def combine_scores(chunks, semantic_scores, bm25_scores)
      sem_max = semantic_scores.max || 1.0
      bm25_max = bm25_scores.max || 1.0

      chunks.each_with_index.map do |chunk, idx|
        sem_norm = sem_max.positive?  ? semantic_scores[idx] / sem_max  : 0.0
        bm25_norm = bm25_max.positive? ? bm25_scores[idx]    / bm25_max : 0.0
        score = @alpha * sem_norm + (1 - @alpha) * bm25_norm

        { chunk: chunk, score: score }
      end
    end

    def build_result(r)
      chunk = r[:chunk]
      {
        content: chunk.content,
        score: r[:score],
        document_id: chunk.document_id,
        chunk_id: chunk.id,
        start_char: chunk.start_char,
        end_char: chunk.end_char
      }
    end
  end
end
