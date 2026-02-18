module Preprocessing
  class Chunker
    DEFAULT_CHUNK_SIZE = 500
    DEFAULT_OVERLAP = 50

    def initialize(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
      @text = text
      @chunk_size = chunk_size
      @overlap = overlap
    end

    def call
      return [] if @text.blank?

      chunks = []
      start_char = 0

      while start_char < @text.length
        end_char = [start_char + @chunk_size, @text.length].min

        # Try to break at word boundary if not at the end
        if end_char < @text.length
          # Look for the last space within the chunk
          last_space = @text.rindex(/\s/, end_char)
          if last_space && last_space > start_char
            end_char = last_space
          end
        end

        chunks << {
          start_char: start_char,
          end_char: end_char,
          content: @text[start_char...end_char]
        }

        # Move start position, accounting for overlap
        start_char = end_char - @overlap
        start_char = end_char if start_char >= @text.length - @overlap

        # Prevent infinite loop
        break if start_char >= @text.length
      end

      chunks
    end

    def self.call(text, **options)
      new(text, **options).call
    end
  end
end
