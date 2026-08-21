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

ActiveRecord::Schema[8.1].define(version: 2026_08_20_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "authors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "bio"
    t.date "born_on"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "books", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.string "isbn"
    t.jsonb "metadata"
    t.boolean "out_of_print", default: false, null: false
    t.integer "pages"
    t.decimal "price", precision: 8, scale: 2
    t.date "published_on"
    t.bigint "publisher_id"
    t.text "synopsis"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_books_on_author_id"
    t.index ["publisher_id"], name: "index_books_on_publisher_id"
  end

  create_table "publishers", force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reviews", force: :cascade do |t|
    t.text "body"
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.integer "rating"
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_reviews_on_book_id"
  end

  add_foreign_key "books", "authors"
  add_foreign_key "books", "publishers"
  add_foreign_key "reviews", "books"
end
