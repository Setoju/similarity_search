class Sentence < ApplicationRecord
  belongs_to :document
  belongs_to :chunk, optional: true

  validates :start_char, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :end_char, presence: true, numericality: { only_integer: true, greater_than: :start_char }

  def content
    document.content[start_char...end_char]
  end
end
