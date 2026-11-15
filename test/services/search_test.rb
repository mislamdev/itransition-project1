# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The full text search.
class SearchTest < ActiveSupport::TestCase
  include DomainHelpers

  setup do
    @inventory = create_inventory(title: "Office equipment", description: "Laptops and printers")
    @field = create_field(inventory: @inventory, title: "Model", field_type: "text")
    @item = create_item(inventory: @inventory, custom_id: "OFF-0001", values: { @field => "ThinkPad X1" })
  end

  test "an inventory is found by its title" do
    assert_includes Search.new("office").inventories, @inventory
  end

  test "an inventory is found by its description" do
    assert_includes Search.new("printers").inventories, @inventory
  end

  test "an item is found by its custom id" do
    assert_includes Search.new("OFF-0001").items, @item
  end

  test "an item is found by the value of a field" do
    assert_includes Search.new("thinkpad").items, @item
  end

  test "the search only looks at the prefix of a word" do
    assert_includes Search.new("OFF-000").items, @item
  end

  test "an empty query finds nothing" do
    assert_empty Search.new("").inventories
    assert_empty Search.new("").items
  end

  test "the search may be limited to one inventory" do
    other = create_inventory(title: "Office equipment")
    other_item = create_item(inventory: other, custom_id: "OFF-0001")

    result = Search.new("OFF-0001", inventory: @inventory).items

    assert_includes result, @item
    refute_includes result, other_item
  end

  test "the tags that start with the text are found" do
    @inventory.update!(tag_list: "hardware")

    assert_includes Search.new("hard").tags, Tag.find_by(name: "hardware")
  end

  test "the search does not break on special characters" do
    assert_empty Search.new("'; DROP TABLE inventories; --").inventories
    assert Inventory.exists?(@inventory.id)
  end
end
