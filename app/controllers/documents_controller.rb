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
    results = Embeddings::DocumentSearch.new(query).call
    render json: results.map { |doc| { content: doc.content } }
  end

  def clear
    Document.delete_all
    render json: { message: 'All documents cleared' }
  end

  private

  def document_params
    params.require(:document).permit(:content)
  end
end
