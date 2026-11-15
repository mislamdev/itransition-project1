# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The items of an inventory.
class ItemTest < ActiveSupport::TestCase
  include DomainHelpers

  setup do
    @owner = create_user
    @collaborator = create_user
    @inventory = create_inventory_with_format(user: @owner)
  end

  test "a custom id is required" do
    item = @inventory.items.new

    refute item.valid?
    assert_includes item.errors.full_messages.join, "Custom"
  end

  test "a custom id may only be used once in an inventory" do
    create_item(inventory: @inventory, custom_id: "INV-1-000001")

    duplicate = @inventory.items.new(custom_id: "INV-1-000001")

    refute duplicate.valid?
  end

  test "the same custom id may be used in another inventory" do
    other = create_inventory_with_format(user: @owner)
    create_item(inventory: @inventory, custom_id: "INV-1-000001")

    item = other.items.new(custom_id: "INV-1-000001")
    item.field_values.build(field: other.fields.create!(title: "Model", field_type: "text"), value: "X")

    assert item.valid?
  end

  test "a custom id that does not follow the format is refused" do
    item = @inventory.items.new(custom_id: "nonsense")

    refute item.valid?
    assert_includes item.errors[:custom_id].join, "format"
  end

  test "a custom id that follows the format is accepted" do
    item = @inventory.items.new(custom_id: "INV-0001-123456")

    assert item.valid?
  end

  test "the values of the custom fields are stored by type" do
    text = create_field(inventory: @inventory, title: "Model", field_type: "text")
    number = create_field(inventory: @inventory, title: "Price", field_type: "number")
    flag = create_field(inventory: @inventory, title: "Broken", field_type: "boolean")

    item = @inventory.items.new
    item.custom_id = CustomId::Generator.new(@inventory).generate
    item.field_values.build(field: text, value: "ThinkPad")
    item.field_values.build(field: number, value: "12.50")
    item.field_values.build(field: flag, value: "1")
    item.save!

    values = item.reload.values
    assert_equal "ThinkPad", values[text.id]
    assert_equal BigDecimal("12.50"), values[number.id]
    assert_equal true, values[flag.id]
  end

  test "a number that is not a number is an error and not an exception" do
    number = create_field(inventory: @inventory, title: "Price", field_type: "number")

    item = @inventory.items.new
    item.custom_id = CustomId::Generator.new(@inventory).generate
    item.field_values.build(field: number, value: "not a number")

    refute item.valid?
    assert_includes item.errors.full_messages.join, "number"
  end

  test "a document field needs a link" do
    document = create_field(inventory: @inventory, title: "Manual", field_type: "document")

    item = @inventory.items.new
    item.custom_id = CustomId::Generator.new(@inventory).generate
    item.field_values.build(field: document, value: "not a link")

    refute item.valid?

    item.field_values.first.value = "https://example.com/manual.pdf"
    assert item.valid?
  end

  test "the values of an item are part of the search text" do
    field = create_field(inventory: @inventory, title: "Model", field_type: "text")
    item = create_item(inventory: @inventory, values: { field => "ThinkPad X1" })

    assert_includes item.reload.search_text, "ThinkPad X1"
    normalized_id = item.custom_id.gsub(/[^\p{L}\p{N}]+/u, " ")
    assert_includes item.search_text, normalized_id
  end

  test "the owner of the inventory may change the item" do
    item = create_item(inventory: @inventory)

    assert item.editable_by?(@owner)
    refute item.editable_by?(create_user)
    refute item.editable_by?(nil)
  end

  test "a user with write access may change the item" do
    InventoryAccess.create!(inventory: @inventory, user: @collaborator)
    item = create_item(inventory: @inventory)

    assert item.editable_by?(@collaborator)
  end

  test "a user may like an item only once" do
    item = create_item(inventory: @inventory)
    user = create_user

    Like.create!(item: item, user: user)

    assert item.liked_by?(user)
    assert_equal 1, item.reload.likes_count

    duplicate = Like.new(item: item, user: user)
    refute duplicate.valid?
  end
end
