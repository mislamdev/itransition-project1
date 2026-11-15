class CreateInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :inventories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.references :category, foreign_key: true
      # Images live in the cloud, the application only stores the URL.
      t.string :image_url
      # When true every authenticated user may add items to the inventory.
      t.boolean :is_public, null: false, default: false
      # Optimistic locking: every save bumps the version, a stale write is rejected.
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :inventories, :title
    add_index :inventories, :created_at
  end
end
