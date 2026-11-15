# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The custom fields of an inventory.
class FieldTest < ActiveSupport::TestCase
  include DomainHelpers

  setup do
    @inventory = create_inventory
  end

  test "a field needs a title" do
    field = @inventory.fields.new(field_type: "text")

    refute field.valid?
  end

  test "the type of a field is known" do
    field = @inventory.fields.new(title: "Model", field_type: "unicorn")

    refute field.valid?
  end

  test "an inventory may have three single line fields" do
    3.times { |index| @inventory.fields.create!(title: "Field #{index}", field_type: "text") }

    field = @inventory.fields.new(title: "One too many", field_type: "text")

    refute field.valid?
    assert_includes field.errors[:field_type].join, "at most 3"
  end

  test "the limit of one type does not affect the other types" do
    3.times { |index| @inventory.fields.create!(title: "Field #{index}", field_type: "text") }

    assert @inventory.fields.new(title: "Price", field_type: "number").valid?
  end

  test "a field may be changed without breaking the limit" do
    field = @inventory.fields.create!(title: "Model", field_type: "text")
    2.times { |index| @inventory.fields.create!(title: "Field #{index}", field_type: "text") }

    assert field.update(title: "Model of the device")
  end
end
