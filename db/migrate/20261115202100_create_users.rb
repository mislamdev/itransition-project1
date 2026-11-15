class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :name, null: false, default: ""
      t.boolean :admin, null: false, default: false
      t.boolean :blocked, null: false, default: false
      t.string :provider
      t.string :uid
      t.string :avatar_url
      t.string :locale, null: false, default: "en"
      t.string :theme, null: false, default: "light"
      # Bumped whenever the account must lose every existing session
      # (blocking, password change, ...). The session stores the value it was
      # issued with, so a mismatch invalidates the session server side.
      t.integer :session_version, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :provider
    add_index :users, :uid
    add_index :users, [:provider, :uid], unique: true
    add_index :users, :name
  end
end
