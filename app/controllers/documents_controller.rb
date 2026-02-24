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

  def chunk_search
    query = params[:query]
    search_type = params[:search_type]&.to_s&.downcase || "cosine"
    results = if search_type == "hybrid"
      Embeddings::HybridSearch.new(query).call
    else
      Embeddings::ChunkSearch.new(query, search_type).call
    end
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

  def rag
    query = params[:query]
    search_type = params[:search_type]&.to_s&.downcase || "cosine"
    rerank = ActiveModel::Type::Boolean.new.cast(params[:rerank]) || false
    rerank_threshold = params[:rerank_threshold]&.to_i || Reranking::LlmReranker::DEFAULT_THRESHOLD

    result = Rag::Query.new(
      query,
      search_type: search_type,
      rerank: rerank,
      rerank_threshold: rerank_threshold
    ).call
    render json: result
  rescue RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index_status
    counts = Document.group(:index_status).count
    total_count = Document.count

    render json: {
      pending: counts["pending"] || 0,
      processing: counts["processing"] || 0,
      completed: counts["completed"] || 0,
      failed: counts["failed"] || 0,
      total: total_count,
      in_progress: (counts["pending"] || 0) + (counts["processing"] || 0)
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
