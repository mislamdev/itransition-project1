# A "like" of an item.
#
# A user may like an item once; the unique index on item_id + user_id makes
# sure that a second like is rejected by the database.
class Like < ApplicationRecord
  belongs_to :item, counter_cache: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :item_id }
end
