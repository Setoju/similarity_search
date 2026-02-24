class Document < ApplicationRecord
  after_create_commit :enqueue_embedding_job

  has_many :chunks, dependent: :destroy
  has_many :sentences, through: :chunks, dependent: :destroy

  validates :content, presence: true
  validates :index_status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :pending_or_processing, -> { where(index_status: %w[pending processing]) }
  scope :completed, -> { where(index_status: "completed") }
  scope :failed, -> { where(index_status: "failed") }

  private

  def enqueue_embedding_job
    DocumentEmbeddingJob.perform_later(id)
  end
end