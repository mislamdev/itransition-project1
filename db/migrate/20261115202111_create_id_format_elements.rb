class CreateIdFormatElements < ActiveRecord::Migration[8.1]
  def change
    create_table :id_format_elements do |t|
      t.references :inventory, null: false, foreign_key: true
      # text | random_20 | random_32 | random_6 | random_9 | guid | datetime | sequence
      t.string :kind, null: false
      t.integer :position, null: false, default: 0
      # The literal text of a "text" element.
      t.string :text
      # Formatting options, e.g. { "padding" => 6, "format" => "%Y%m%d" }.
      t.json :options, null: false, default: {}

      t.timestamps
    end

    add_index :id_format_elements, [:inventory_id, :position]
  end
end
