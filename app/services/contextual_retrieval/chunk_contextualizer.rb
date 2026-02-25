module ContextualRetrieval
  # Generates short contextual descriptions for document chunks using
  # Google Gemini's cached content API.
  #
  # The full document is uploaded once as cached content so that it is not
  # re-sent with every per-chunk request. Each chunk then receives a
  # succinct 1-2 sentence context that situates it within the document,
  # which is later prepended to improve embedding and search quality.
  #
  # If API-level caching fails (e.g. document too small), the service
  # falls back to including the document directly in each prompt.
  class ChunkContextualizer
    def initialize(document_content, chunks)
      @document_content = document_content
      @chunks = chunks
    end

    def self.call(document_content, chunks)
      new(document_content, chunks).call
    end

    def call
      return @chunks if @chunks.empty?

      gemini = Embeddings::GoogleGeminiClient.new
      cache_name = nil

      # Content under 4k tokens will fail caching because it's too small to be worth caching, so we rescue and fall back to direct generation in that case.
      begin
        cache_name = gemini.create_cached_content(cache_body)
        contextualize_with_cache(gemini, cache_name)
      rescue => e
        Rails.logger.warn "[ChunkContextualizer] Cached generation failed (#{e.message}), falling back to direct prompts"
        contextualize_directly(gemini)
      ensure
        gemini.delete_cached_content(cache_name) if cache_name
      end
    end

    private

    def contextualize_with_cache(gemini, cache_name)
      @chunks.map do |chunk|
        context = gemini.generate_with_cache(cache_name, chunk_prompt(chunk[:content]))
        chunk.merge(context: context.strip)
      end
    end

    def contextualize_directly(gemini)
      @chunks.map do |chunk|
        context = gemini.generate(direct_prompt(chunk[:content]))
        chunk.merge(context: context.strip)
      rescue => e
        Rails.logger.warn "[ChunkContextualizer] Skipping context for chunk: #{e.message}"
        chunk.merge(context: "")
      end
    end

    def cache_body
      <<~TEXT.strip
        <document>
        #{@document_content}
        </document>
      TEXT
    end

    def chunk_prompt(chunk_content)
      <<~PROMPT.strip
        Here is a chunk from the document provided earlier:

        <chunk>
        #{chunk_content}
        </chunk>

        Give a short, succinct context (1-2 sentences) to situate this chunk within the overall document for search retrieval purposes.
        Return ONLY the contextual description, nothing else.
      PROMPT
    end

    def direct_prompt(chunk_content)
      <<~PROMPT.strip
        <document>
        #{@document_content}
        </document>

        Here is a chunk from the above document:

        <chunk>
        #{chunk_content}
        </chunk>

        Give a short, succinct context (1-2 sentences) to situate this chunk within the overall document for search retrieval purposes.
        Return ONLY the contextual description, nothing else.
      PROMPT
    end
  end
end
