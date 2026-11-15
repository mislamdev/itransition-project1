# The last number that was handed out for a "sequence" element of an
# inventory.
#
# The counter lives in the database so that two users adding an item at the
# same time never receive the same number.  It is only increased, never
# decreased, so that a number is never used twice.
class InventorySequence < ApplicationRecord
  belongs_to :inventory
  belongs_to :id_format_element

  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # The uniqueness of the counter (one row per inventory and element) is
  # enforced by the unique index of the table, not by a validation: the
  # generator creates the row with `create_or_find_by!`, which relies on the
  # database to report the conflict.
end
