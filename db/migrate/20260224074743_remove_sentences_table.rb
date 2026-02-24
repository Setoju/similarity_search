class RemoveSentencesTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :sentences
  end
end
