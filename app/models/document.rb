class Document < ApplicationRecord
  before_create :generate_embedding

  validates :content, presence: true

  private

  def generate_embedding
    Embeddings::DocumentEmbedding.new(self).call
  end
end