class DocumentsController < ApplicationController
  def index
    documents = Document.all
    render json: documents
  end
  
  def create
    document = Document.create!(document_params)
    render json: document
  end

  def search
    query = params[:query]
    search_type = params[:search_type]&.to_s&.downcase || "cosine"
    results = Embeddings::DocumentSearch.new(query, search_type).call
    render json: results.map { |doc| { content: doc.content } }
  end

  def sentence_search
    query = params[:query]
    search_type = params[:search_type]&.to_s&.downcase || "cosine"
    results = Embeddings::SentenceSearch.new(query, search_type).call
    render json: results.map { |result|
      {
        content: result[:content],
        score: result[:score],
        document_id: result[:document_id],
        chunk_id: result[:chunk_id],
        start_char: result[:start_char],
        end_char: result[:end_char]
      }
    }
  end

  def index_status
    pending_count = Document.where(index_status: "pending").count
    processing_count = Document.where(index_status: "processing").count
    completed_count = Document.where(index_status: "completed").count
    failed_count = Document.where(index_status: "failed").count
    total_count = Document.count

    render json: {
      pending: pending_count,
      processing: processing_count,
      completed: completed_count,
      failed: failed_count,
      total: total_count,
      in_progress: pending_count + processing_count
    }
  end

  def clear
    Document.destroy_all
    render json: { message: 'All documents cleared' }
  end

  private

  def document_params
    params.require(:document).permit(:content)
  end
end
