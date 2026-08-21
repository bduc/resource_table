class CreateLayoutFixtures < ActiveRecord::Migration[8.1]
  def change
    # For SettingsTable: one row per (owner, key).
    create_table :author_settings do |t|
      t.references :author, null: false, foreign_key: true
      t.string :key, null: false
      t.jsonb :value, null: false, default: {}
      t.timestamps
      t.index [ :author_id, :key ], unique: true
    end

    # For JsonColumn: every layout in one column on the owner.
    add_column :authors, :table_layouts, :jsonb, null: false, default: {}
  end
end
