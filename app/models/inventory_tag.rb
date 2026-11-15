# The connection between an inventory and a tag.
class InventoryTag < ApplicationRecord
  belongs_to :inventory
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :inventory_id }
end
