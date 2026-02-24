class DocumentEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    document.update!(index_status: "processing")

    begin
      client = Embeddings::OllamaClient.new

      create_document_embedding(document, client)

      chunks = create_chunks(document, client)

      create_sentences(document, chunks)

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
    created_chunks = []

    chunk_data.each do |chunk_info|
      normalized_content = Preprocessing::Normalizer.call(chunk_info[:content])
      embedding = client.embed(normalized_content)

      chunk = document.chunks.create!(
        start_char: chunk_info[:start_char],
        end_char: chunk_info[:end_char],
        embedding: embedding
      )

      created_chunks << { chunk: chunk, content: chunk_info[:content] }
    end

    created_chunks
  end

  def create_sentences(document, chunks)
    chunks.each do |chunk_data|
      chunk = chunk_data[:chunk]
      content = chunk_data[:content]

      sentences_data = Preprocessing::Sentencer.call(content, offset: chunk.start_char)

      sentences_data.each do |sentence_info|
        next if sentence_info[:content].blank?

        chunk.sentences.create!(
          document: document,
          start_char: sentence_info[:start_char],
          end_char: sentence_info[:end_char]
        )
      end
    end
  end
end
