module Embeddings
    class DocumentEmbedding
        def initialize(document)
            @document = document
        end

        def call
            return if @document.content.blank?

            normalized_text = Preprocessing::Normalizer.call(@document.content)
            client = Embeddings::OllamaClient.new
            embedding_result = client.embed(normalized_text)

            if embedding_result.is_a?(Array) && embedding_result.any?
            @document.embedding = embedding_result
            else
            Rails.logger.error "Failed to generate embedding for document: #{@document.id}"
            @document.embedding = [0.0] * 768
            end
        end
    end
end