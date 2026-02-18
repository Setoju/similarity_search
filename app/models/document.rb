class Document < ApplicationRecord
  before_create :generate_embedding

  has_many :chunks, dependent: :destroy
  has_many :sentences, dependent: :destroy

  validates :content, presence: true

  private

  def generate_embedding
    Embeddings::DocumentEmbedding.new(self).call
  end
end