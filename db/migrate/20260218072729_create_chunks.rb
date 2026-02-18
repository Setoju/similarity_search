class CreateChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.integer :start_char, null: false
      t.integer :end_char, null: false
      t.float :embedding, null: true, array: true

      t.timestamps
    end
  end
end
