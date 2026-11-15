# Grants a user write access to an inventory.
#
# The owner of an inventory decides who may add, change and delete its items.
# When the inventory is public everybody who is signed in may do so, and this
# table is then not used at all.
class InventoryAccess < ApplicationRecord
  belongs_to :inventory
  belongs_to :user

  validates :user_id, uniqueness: { scope: :inventory_id }
  validate :owner_is_not_added

  scope :sorted, -> { joins(:user).order(Arel.sql("LOWER(users.name) ASC, LOWER(users.email) ASC")) }

  private

  def owner_is_not_added
    errors.add(:user_id, "already owns this inventory") if inventory.present? && inventory.user_id == user_id
  end
end
