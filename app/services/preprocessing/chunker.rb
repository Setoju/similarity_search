module Preprocessing
  class Chunker
    DEFAULT_CHUNK_SIZE = 500
    DEFAULT_OVERLAP = 1
    DEFAULT_SEMANTIC_THRESHOLD = 0.8

    def initialize(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP, embedding_client: nil, semantic_threshold: DEFAULT_SEMANTIC_THRESHOLD)
      @text = text
      @chunk_size = chunk_size
      @overlap = overlap
      @embedding_client = embedding_client
      @semantic_threshold = semantic_threshold
    end

    def call
      return [] if @text.blank?

      sentences = segment_sentences
      return [] if sentences.empty?

      build_chunks(sentences)
    end

    def self.call(text, **options)
      new(text, **options).call
    end

    private

    def segment_sentences
      raw_sentences = PragmaticSegmenter::Segmenter.new(text: @text).segment
      return [] if raw_sentences.empty?

      mapped = []
      search_from = 0

      raw_sentences.each do |sentence|
        stripped = sentence.strip
        idx = @text.index(stripped, search_from)
        next unless idx

        mapped << { content: stripped, start_char: idx, end_char: idx + stripped.length }
        search_from = idx + stripped.length
      end

      mapped
    end

    def build_chunks(sentences)
      semantic_chunks = build_semantic_chunks(sentences)
      return semantic_chunks if semantic_chunks

      build_size_based_chunks(sentences)
    end

    def build_semantic_chunks(sentences)
      return nil unless @embedding_client

      vectors = sentence_vectors(sentences)
      return nil if vectors.empty?

      chunks = []
      group = []
      group_length = 0

      sentences.each_with_index do |sentence, idx|
        if idx.positive?
          similarity = Similarity::Cosine.call(vectors[idx - 1], vectors[idx])
          if similarity < @semantic_threshold
            chunks << flush_group(group) if group.any?
            group = group.last(@overlap)
            group_length = group_total_length(group)
          end
        end

        candidate_length = group_length + (group.empty? ? 0 : 1) + sentence[:content].length

        if group.any? && candidate_length > @chunk_size
          chunks << flush_group(group)
          group = group.last(@overlap)
          group_length = group_total_length(group)
        end

        group << sentence
        group_length = group_total_length(group)
      end

      chunks << flush_group(group) if group.any?
      chunks
    rescue StandardError => e
      Rails.logger.warn("[Chunker] Semantic chunking failed (#{e.message}), falling back to size-based chunking")
      nil
    end

    def sentence_vectors(sentences)
      sentences.map do |sentence|
        normalized = Preprocessing::Normalizer.call(sentence[:content])
        vector = @embedding_client.embed(normalized)
        raise "Missing sentence embedding" unless vector.is_a?(Array) && vector.any?

        vector
      end
    end

    def build_size_based_chunks(sentences)
      chunks = []
      group = []
      group_length = 0

      sentences.each do |sentence|
        candidate_length = group_length + (group.empty? ? 0 : 1) + sentence[:content].length

        if group.any? && candidate_length > @chunk_size
          chunks << flush_group(group)
          group = group.last(@overlap)
          group_length = group_total_length(group)
        end

        group << sentence
        group_length = group_total_length(group)
      end

      chunks << flush_group(group) if group.any?
      chunks
    end

    def group_total_length(group)
      group.map { |s| s[:content].length }.sum + [group.length - 1, 0].max
    end

    def flush_group(group)
      {
        start_char: group.first[:start_char],
        end_char: group.last[:end_char],
        content: group.map { |s| s[:content] }.join(" ")
      }
    end
  end
end
