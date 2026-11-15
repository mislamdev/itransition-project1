# Adds the item counter to the inventories.
#
# The counter is maintained by Active Record (counter cache), so that the
# "most popular inventories" list never has to count in Ruby and never has to
# run a query per row.
class AddItemsCountToInventories < ActiveRecord::Migration[8.1]
  def up
    add_column :inventories, :items_count, :integer, null: false, default: 0

    # Backfill the rows that already exist.
    execute <<~SQL.squish
      UPDATE inventories
      SET items_count = (SELECT COUNT(*) FROM items WHERE items.inventory_id = inventories.id)
    SQL
  end

  def down
    remove_column :inventories, :items_count
  end
end
