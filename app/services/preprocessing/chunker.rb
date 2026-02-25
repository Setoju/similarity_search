module Preprocessing
  class Chunker
    DEFAULT_CHUNK_SIZE = 500
    DEFAULT_OVERLAP = 1  # number of sentences to overlap between chunks

    def initialize(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
      @text = text
      @chunk_size = chunk_size
      @overlap = overlap
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
      chunks = []
      group = []
      group_length = 0

      sentences.each do |sentence|
        candidate_length = group_length + (group.empty? ? 0 : 1) + sentence[:content].length

        if group.any? && candidate_length > @chunk_size
          chunks << flush_group(group)
          group = group.last(@overlap)
          group_length = group.map { |s| s[:content].length }.sum + [group.length - 1, 0].max
        end

        group << sentence
        group_length = group.map { |s| s[:content].length }.sum + [group.length - 1, 0].max
      end

      chunks << flush_group(group) if group.any?
      chunks
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
