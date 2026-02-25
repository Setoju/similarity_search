# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_25_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.integer "start_char", null: false
    t.integer "end_char", null: false
    t.float "embedding", null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "context"
    t.index ["document_id"], name: "index_chunks_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content", null: false
    t.float "embedding", comment: "768-dimensional embeddings from Google's text-embedding-004 model", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "index_status", default: "pending", null: false
  end

  add_foreign_key "chunks", "documents"
end
