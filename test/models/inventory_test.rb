# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The permissions of the inventories and the items.
class InventoryTest < ActiveSupport::TestCase
  include DomainHelpers

  setup do
    @owner = create_user
    @collaborator = create_user
    @stranger = create_user
    @admin = create_admin
    @inventory = create_inventory(user: @owner)
  end

  test "the owner may change the inventory" do
    assert @inventory.editable_by?(@owner)
    assert @inventory.writable_by?(@owner)
  end

  test "an administrator may change every inventory" do
    assert @inventory.editable_by?(@admin)
    assert @inventory.writable_by?(@admin)
  end

  test "a stranger may not change the inventory" do
    refute @inventory.editable_by?(@stranger)
    refute @inventory.writable_by?(@stranger)
  end

  test "a guest may neither read the access nor change anything" do
    refute @inventory.editable_by?(nil)
    refute @inventory.writable_by?(nil)
  end

  test "everybody may read an inventory" do
    assert @inventory.accessible_by?(nil)
    assert @inventory.accessible_by?(@stranger)
  end

  test "a user with write access may add items" do
    InventoryAccess.create!(inventory: @inventory, user: @collaborator)

    refute @inventory.editable_by?(@collaborator)
    assert @inventory.writable_by?(@collaborator)
  end

  test "everybody may add items to a public inventory" do
    @inventory.update!(is_public: true)

    assert @inventory.writable_by?(@stranger)
    refute @inventory.editable_by?(@stranger)
  end

  test "the tags are stored as a list" do
    @inventory.update!(tag_list: "office, laptops")

    assert_equal %w[laptops office], @inventory.tags.map(&:name).sort
    assert_equal "office, laptops", @inventory.tag_list
  end

  test "a tag that is used twice is only stored once" do
    @inventory.update!(tag_list: "office, Office")

    assert_equal 1, @inventory.tags.count
  end

  test "the format of the custom ids is readable" do
    @inventory.id_format_elements.create!(kind: "fixed", text: "X-", position: 0)
    @inventory.id_format_elements.create!(kind: "random_6", position: 1)
    @inventory.reload

    assert_equal "X-{random_6}", @inventory.custom_id_format
  end

  test "the number of items is kept in a counter" do
    assert_equal 0, @inventory.reload.items_count

    create_item(inventory: @inventory)

    assert_equal 1, @inventory.reload.items_count
  end
end
