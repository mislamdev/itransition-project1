class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :inventory, null: false, foreign_key: true
      # The custom id is unique *within* an inventory; the database enforces it.
      t.string :custom_id, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.integer :likes_count, null: false, default: 0
      # Denormalised copy of the searchable text, kept in sync by the Item model.
      t.text :search_text, null: false, default: ""
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :items, [:inventory_id, :custom_id], unique: true
    add_index :items, :created_at
  end
end
