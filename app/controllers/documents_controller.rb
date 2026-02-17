class DocumentsController < ApplicationController
  def create
    document = Document.create!(document_params)
    render json: document
  end

  def search
    query = params[:query]
    results = Embeddings::DocumentSearch.new(query).call
    render json: results.map { |doc| { content: doc.content } }
  end

  private

  def document_params
    params.require(:document).permit(:content)
  end
end
