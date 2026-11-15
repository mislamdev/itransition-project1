# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The generation of the custom ids.
class CustomIdGeneratorTest < ActiveSupport::TestCase
  include DomainHelpers

  test "the generated id follows the format of the inventory" do
    inventory = create_inventory_with_format
    id = CustomId::Generator.new(inventory).generate

    assert_match(/\AINV-\d+-\d{6}\z/, id)
    assert inventory.custom_id_formatter.matches?(id)
  end

  test "every id of an inventory is different" do
    inventory = create_inventory_with_format
    ids = 5.times.map { CustomId::Generator.new(inventory).generate }

    assert_equal ids.uniq.size, ids.size
  end

  test "the sequence grows with every item" do
    inventory = create_inventory_with_format
    first = CustomId::Generator.new(inventory).generate
    second = CustomId::Generator.new(inventory).generate

    assert_equal 1, first[/\AINV-(\d+)-/, 1].to_i
    assert_equal 2, second[/\AINV-(\d+)-/, 1].to_i
  end

  test "an inventory without a format still gets an id" do
    inventory = create_inventory

    assert CustomId::Generator.new(inventory).generate.present?
  end

  test "the preview shows the id that would be used next" do
    inventory = create_inventory_with_format
    preview = CustomId::Generator.new(inventory).preview

    assert_match(/\AINV-\d+-\d{6}\z/, preview)
  end

  test "the preview of a format that is not saved yet works as well" do
    inventory = create_inventory
    elements = [{ kind: "fixed", text: "NEW-" }, { kind: "random_9" }]

    preview = CustomId::Generator.new(inventory).preview(elements)

    assert_match(/\ANEW-\d{9}\z/, preview)
  end

  test "an id that is already used is not handed out twice" do
    inventory = create_inventory_with_format
    item = create_item(inventory: inventory)

    # The generator never returns an id that is used already.
    10.times do
      id = CustomId::Generator.new(inventory).generate
      refute_equal item.custom_id, id
    end
  end
end
