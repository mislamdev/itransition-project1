# frozen_string_literal: true

# Authorization policy helpers.
#
# The rules come straight from the requirements:
#
#   * every inventory and every item is viewable by everybody, anonymous
#     visitors included (read only access);
#   * anonymous visitors may not create inventories, add, edit or delete
#     items, comment or like anything;
#   * the creator of an inventory may do everything with it;
#   * users explicitly granted write access may add, edit and delete the
#     items of that inventory;
#   * administrators may do everything, acting as if they were the owner of
#     every inventory.
#
# The concern only answers questions; the actual enforcement is done by the
# controllers through `before_action` filters. The same predicates are
# exposed to the views so that the interface can hide what a visitor is not
# allowed to do.
#
# The `editable_by?` / `writable_by?` predicates themselves live on the
# Inventory and Item models (owned by the backend), this concern only adds
# the session related parts: "is anybody signed in at all?" and "is the
# current visitor an administrator?".
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :can_edit_inventory?, :can_write_items?, :can_view_inventory?,
                  :can_edit_item?, :can_comment?, :can_like?, :can_administer_users?
  end

  # Can the current visitor change the settings of the inventory (fields,
  # access list, custom id format, ...)?
  def can_edit_inventory?(inventory)
    return false if inventory.blank?
    return false unless user_signed_in?

    # Administrators act as the owner of every inventory.
    return true if current_user.admin?

    inventory.editable_by?(current_user)
  end

  # Can the current visitor add, edit or delete items of the inventory?
  def can_write_items?(inventory)
    return false if inventory.blank?
    return false unless user_signed_in?

    return true if current_user.admin?

    inventory.writable_by?(current_user)
  end

  # Can the current visitor change this particular item?
  def can_edit_item?(item)
    return false if item.blank?
    return false unless user_signed_in?

    return true if current_user.admin?

    item.editable_by?(current_user)
  end

  # Reading is public: every inventory is viewable by everybody.
  def can_view_inventory?(_inventory = nil)
    true
  end

  # Comments and likes require an account.
  def can_comment?(_inventory = nil)
    user_signed_in?
  end

  def can_like?(_item = nil)
    user_signed_in?
  end

  # Only administrators reach the user administration pages.
  def can_administer_users?
    admin?
  end
end
