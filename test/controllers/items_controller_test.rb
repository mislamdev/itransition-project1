# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The items of an inventory: who may add, change and delete them.
class ItemsControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers
  include DomainHelpers

  setup do
    @owner = create_user
    @collaborator = create_user
    @stranger = create_user
    @admin = create_admin
    @inventory = create_inventory_with_format(user: @owner)
    @field = create_field(inventory: @inventory, title: "Model", field_type: "text")
    @item = create_item(inventory: @inventory, values: { @field => "ThinkPad" })
    InventoryAccess.create!(inventory: @inventory, user: @collaborator)
  end

  # --- reading ---------------------------------------------------------

  test "a guest sees an item" do
    get item_path(@item)

    assert_response :success
  end

  test "a guest sees the items of an inventory" do
    get inventory_items_path(@inventory)

    assert_response :success
  end

  # --- creating --------------------------------------------------------

  test "a guest may not add an item" do
    assert_no_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { custom_id: "INV-0001-000001" } }
    end

    assert_redirected_to sign_in_path
  end

  test "the owner adds an item and the id is generated" do
    sign_in_as @owner

    assert_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { values: { @field.id => "MacBook" } } }
    end

    item = Item.order(:id).last
    assert_match(/\AINV-\d+-\d{6}\z/, item.custom_id)
    assert_equal "MacBook", item.values[@field.id]
  end

  test "the owner writes a custom id by hand" do
    sign_in_as @owner

    post inventory_items_path(@inventory), params: { item: { custom_id: "INV-0007-123456" } }

    assert_equal "INV-0007-123456", Item.order(:id).last.custom_id
  end

  test "a custom id that does not follow the format is refused" do
    sign_in_as @owner

    assert_no_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { custom_id: "nonsense" } }
    end

    assert_response :unprocessable_entity
  end

  test "a user with write access adds an item" do
    sign_in_as @collaborator

    assert_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { values: { @field.id => "Shared" } } }
    end
  end

  test "a stranger may not add an item to a private inventory" do
    sign_in_as @stranger

    assert_no_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { values: { @field.id => "Nope" } } }
    end

    assert_response :forbidden
  end

  test "a stranger may add an item to a public inventory" do
    @inventory.update!(is_public: true)
    sign_in_as @stranger

    assert_difference("Item.count") do
      post inventory_items_path(@inventory), params: { item: { values: { @field.id => "Public" } } }
    end
  end

  # --- changing --------------------------------------------------------

  test "the owner changes an item" do
    sign_in_as @owner

    patch item_path(@item), params: { item: { values: { @field.id => "Changed" } } }

    assert_redirected_to inventory_path(@inventory)
    assert_equal "Changed", @item.reload.values[@field.id]
  end

  test "a stranger may not change an item" do
    sign_in_as @stranger

    patch item_path(@item), params: { item: { values: { @field.id => "Nope" } } }

    assert_response :forbidden
    assert_equal "ThinkPad", @item.reload.values[@field.id]
  end

  test "the owner deletes an item" do
    sign_in_as @owner

    assert_difference("Item.count", -1) do
      delete item_path(@item)
    end
  end

  # --- the automatic saving --------------------------------------------

  test "the automatic saving answers with the new version" do
    sign_in_as @owner

    patch item_path(@item),
          params: { item: { values: { @field.id => "Autosaved" }, lock_version: @item.lock_version } },
          as: :json

    assert_response :success
    assert_equal @item.reload.lock_version, response.parsed_body["version"]
  end

  test "a stale automatic saving is answered with a conflict" do
    sign_in_as @owner
    stale_version = @item.lock_version
    @item.update!(custom_id: "INV-0009-999999")

    patch item_path(@item),
          params: { item: { values: { @field.id => "Autosaved" }, lock_version: stale_version } },
          as: :json

    assert_response :conflict
    assert_equal "conflict", response.parsed_body["error"]
  end
end
