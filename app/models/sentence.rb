class Sentence < ApplicationRecord
    belongs_to :document

    validates :start_char, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :end_char, presence: true, numericality: { only_integer: true, greater_than: :start_char }
    validates :embedding, presence: true
end
