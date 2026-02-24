class RemoveEmbeddingFromSentences < ActiveRecord::Migration[8.0]
  def change
    remove_column :sentences, :embedding, :float, array: true
  end
end
