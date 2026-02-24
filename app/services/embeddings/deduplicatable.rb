module Embeddings
  # Mixin that provides content-based deduplication for search result sets.
  #
  # Including classes call +deduplicate+ with their scored result array and
  # a block that extracts the text content from each element.  Results
  # must already be sorted before deduplication so that the highest-scored
  # copy of any duplicate is the one that is kept.
  #
  # Example (tuple style used by ChunkSearch):
  #   deduplicate(scored) { |chunk, _score| chunk.content }
  #
  # Example (hash style used by HybridSearch):
  #   deduplicate(scored) { |r| r[:chunk].content }
  module Deduplicatable
    private

    def deduplicate(items, &content_for)
      seen = {}
      items.each_with_object([]) do |item, unique| # creates array and passes is as unique
        key = content_fingerprint(content_for.call(item))
        next if seen.key?(key)

        seen[key] = true
        unique << item
      end
    end

    def content_fingerprint(text)
      Digest::SHA256.hexdigest(text.to_s.downcase.gsub(/\s+/, " ").strip)
    end
  end
end
