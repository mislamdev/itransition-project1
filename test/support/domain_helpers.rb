# frozen_string_literal: true

require Rails.root.join("test/support/authentication_helpers.rb")

# Helpers that build the objects of the domain for the tests.
module DomainHelpers
  # Domain tests need accounts too. Including the authentication helpers keeps
  # `create_user` available without duplicating the account setup here.
  include AuthenticationHelpers

  # The number of items that are created by the helpers.
  DEFAULT_ITEM_COUNT = 1

  # Creates an inventory.
  def create_inventory(user: nil, title: "Inventory", **attributes)
    user ||= create_user
    Inventory.create!(user: user, title: title, **attributes)
  end

  # Creates a custom field of an inventory.
  def create_field(inventory:, title: "Field", field_type: "text", **attributes)
    inventory.fields.create!(title: title, field_type: field_type, **attributes)
  end

  # Creates an item of an inventory.
  #
  # The custom id is generated from the format of the inventory, exactly like
  # the controller does it.
  def create_item(inventory:, custom_id: nil, created_by: nil, values: {}, **attributes)
    item = inventory.items.new(created_by: created_by, **attributes)
    item.custom_id = custom_id || CustomId::Generator.new(inventory).generate

    values.each do |field, value|
      item.field_values.build(field: field, value: value)
    end

    item.save!
    item
  end

  # Creates an inventory with a custom id format.
  #
  # The format is "PREFIX-<sequence>-<random>" by default.
  def create_inventory_with_format(user: nil, **attributes)
    inventory = create_inventory(user: user, **attributes)
    inventory.id_format_elements.create!(kind: "fixed", text: "INV-", position: 0)
    inventory.id_format_elements.create!(kind: "sequence", position: 1)
    inventory.id_format_elements.create!(kind: "fixed", text: "-", position: 2)
    inventory.id_format_elements.create!(kind: "random_6", position: 3)
    inventory.reload
  end
end
