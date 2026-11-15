class CreateInventorySequences < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_sequences do |t|
      t.references :inventory, null: false, foreign_key: true
      t.references :id_format_element, null: false, foreign_key: true
      # The last number handed out for this element.
      t.integer :value, null: false, default: 0

      t.timestamps
    end

    add_index :inventory_sequences, [:inventory_id, :id_format_element_id], unique: true
  end
end
