class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.text :content, null: false
      t.float :embedding, array: true

      t.timestamps
    end
  end
end
