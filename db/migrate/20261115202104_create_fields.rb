class CreateFields < ActiveRecord::Migration[8.1]
  def change
    create_table :fields do |t|
      t.references :inventory, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      # text | textarea | number | document | boolean | select
      t.string :field_type, null: false
      # Whether the field is rendered as a column of the items table.
      t.boolean :show_in_table, null: false, default: true
      t.integer :position, null: false, default: 0
      # Type specific options, e.g. { "values" => [...] } for a select field.
      t.json :options, null: false, default: {}

      t.timestamps
    end

    add_index :fields, [:inventory_id, :position]
    add_index :fields, :field_type
  end
end
