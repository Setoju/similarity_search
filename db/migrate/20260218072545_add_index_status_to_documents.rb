class AddIndexStatusToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :index_status, :string, null: false, default: "pending"
  end
end
