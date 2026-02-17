module Embeddings
    class DocumentSearch
        def initialize(query, top: 5)
            @query = query
            @top = top
        end

        def call
            client = Embeddings::OllamaClient.new
            query_vector = client.embed(Preprocessing::Normalizer.call(@query))

            all_docs = Document.where.not(embedding: nil)

            scored = all_docs.map do |doc|
                if doc.embedding&.is_a?(Array) && query_vector&.is_a?(Array)
                    [doc, Similarity::Cosine.call(query_vector, doc.embedding)]
                else
                    nil
                end
            end.compact

            scored.sort_by { |_, score| -score }.first(@top).map(&:first)
        end
    end
end