class AddContextToChunks < ActiveRecord::Migration[8.0]
  def change
    add_column :chunks, :context, :text
  end
end
