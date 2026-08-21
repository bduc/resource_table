class CreateDummyDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :publishers do |t|
      t.string :name, null: false
      t.string :country
      t.timestamps
    end

    create_table :authors do |t|
      t.string :name, null: false
      t.date :born_on
      t.text :bio
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :books do |t|
      t.string :title, null: false
      t.string :isbn
      t.integer :pages
      t.decimal :price, precision: 8, scale: 2
      t.date :published_on
      t.boolean :out_of_print, default: false, null: false
      t.text :synopsis
      t.jsonb :metadata
      t.references :author, null: false, foreign_key: true
      t.references :publisher, foreign_key: true
      t.timestamps
    end

    create_table :reviews do |t|
      t.integer :rating
      t.text :body
      t.references :book, null: false, foreign_key: true
      t.timestamps
    end
  end
end
