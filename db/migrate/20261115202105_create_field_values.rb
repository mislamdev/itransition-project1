class CreateFieldValues < ActiveRecord::Migration[8.1]
  def change
    create_table :field_values do |t|
      t.references :item, null: false, foreign_key: true
      t.references :field, null: false, foreign_key: true
      # One column per type keeps the table indexable and avoids casting in SQL.
      t.text :text_value
      t.decimal :number_value, precision: 20, scale: 6
      t.boolean :boolean_value

      t.timestamps
    end

    add_index :field_values, [:item_id, :field_id], unique: true
  end
end
