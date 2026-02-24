module Embeddings
    class DocumentSearch
        include Deduplicatable
        
        def initialize(query, search_type = 'cosine', top: 5, threshold: 0.6)
            @query = query
            @top = top
            @threshold = threshold
            @similarity_calculator = Similarity::Resolver.call(search_type)
        end

        def call
            client = Embeddings::OllamaClient.new
            query_vector = client.embed(Preprocessing::Normalizer.call(@query))

            all_docs = Document.where.not(embedding: nil)

            scored = all_docs.filter_map do |doc|
                next unless doc.embedding&.is_a?(Array) && query_vector&.is_a?(Array)
                
                score = @similarity_calculator.call(query_vector, doc.embedding)
                [doc, score]
            end

            scored
                .select { |_, score| score > @threshold }
                .sort_by { |_, score| -score }
                .then { |results| deduplicate(results) { |(doc, _)| doc.content } }
                .first(@top)
                .map { |doc, score| build_result(doc, score) }
        end
        
        private
        
        def build_result(doc, score)
            {
                content: doc.content,
                score: score,
                id: doc.id
            }
        end
    end
end