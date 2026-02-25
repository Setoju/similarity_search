class DocumentEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    document.update!(index_status: "processing")

    begin
      client = Embeddings::OllamaClient.new

      create_document_embedding(document, client)

      create_chunks(document, client)

      document.update!(index_status: "completed")
    rescue StandardError => e
      Rails.logger.error "DocumentEmbeddingJob failed for document #{document_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      document.update!(index_status: "failed")
    end
  end

  private

  def create_document_embedding(document, client)
    normalized_text = Preprocessing::Normalizer.call(document.content)
    embedding = client.embed(normalized_text)

    if embedding.is_a?(Array) && embedding.any?
      document.update!(embedding: embedding)
    else
      Rails.logger.error "Failed to generate embedding for document: #{document.id}"
      document.update!(embedding: [0.0] * 768)
    end
  end

  def create_chunks(document, client)
    chunk_data = Preprocessing::Chunker.call(document.content)
    return [] if chunk_data.empty?

    # Context generation for each chunk
    chunk_data = ContextualRetrieval::ChunkContextualizer.call(document.content, chunk_data)

    chunk_data.each do |chunk_info|
      contextualized = chunk_info[:context].present? ? "#{chunk_info[:context]} #{chunk_info[:content]}" : chunk_info[:content]

      normalized_content = Preprocessing::Normalizer.call(contextualized)
      embedding = client.embed(normalized_content)

      chunk = document.chunks.create!(
        start_char: chunk_info[:start_char],
        end_char: chunk_info[:end_char],
        context: chunk_info[:context],
        embedding: embedding
      )
    end
  end
end
