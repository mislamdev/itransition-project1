# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The pages of the inventories and the rules who may change them.
class InventoriesControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers
  include DomainHelpers

  setup do
    @owner = create_user
    @collaborator = create_user
    @stranger = create_user
    @admin = create_admin
    @inventory = create_inventory(user: @owner, title: "Old title")
    InventoryAccess.create!(inventory: @inventory, user: @collaborator)
  end

  # --- reading ---------------------------------------------------------

  test "a guest sees an inventory" do
    get inventory_path(@inventory)

    assert_response :success
  end

  test "a guest sees the list of the inventories" do
    get inventories_path

    assert_response :success
  end

  test "a guest sees the statistics of an inventory" do
    get statistics_inventory_path(@inventory)

    # The statistics belong to the owner.
    assert_redirected_to sign_in_path
  end

  # --- creating --------------------------------------------------------

  test "a guest may not create an inventory" do
    get new_inventory_path

    assert_redirected_to sign_in_path
  end

  test "a user creates an inventory" do
    sign_in_as @owner

    assert_difference("Inventory.count") do
      post inventories_path, params: { inventory: { title: "New inventory", description: "Hello" } }
    end

    assert_redirected_to inventory_path(Inventory.order(:id).last)
  end

  test "an inventory without a title is refused" do
    sign_in_as @owner

    assert_no_difference("Inventory.count") do
      post inventories_path, params: { inventory: { title: "" } }
    end

    assert_response :unprocessable_entity
  end

  # --- changing --------------------------------------------------------

  test "the owner changes the settings" do
    sign_in_as @owner

    patch inventory_path(@inventory), params: { inventory: { title: "New title" } }

    assert_redirected_to inventory_path(@inventory)
    assert_equal "New title", @inventory.reload.title
  end

  test "an administrator changes the settings of another inventory" do
    sign_in_as @admin

    patch inventory_path(@inventory), params: { inventory: { title: "Changed by the admin" } }

    assert_equal "Changed by the admin", @inventory.reload.title
  end

  test "a user with write access may not change the settings" do
    sign_in_as @collaborator

    patch inventory_path(@inventory), params: { inventory: { title: "Nope" } }

    assert_response :forbidden
    assert_equal "Old title", @inventory.reload.title
  end

  test "a guest may not change the settings" do
    patch inventory_path(@inventory), params: { inventory: { title: "Nope" } }

    assert_redirected_to sign_in_path
    assert_equal "Old title", @inventory.reload.title
  end

  test "the owner deletes the inventory" do
    sign_in_as @owner

    assert_difference("Inventory.count", -1) do
      delete inventory_path(@inventory)
    end
  end

  # --- the automatic saving --------------------------------------------

  test "the automatic saving answers with the new version" do
    sign_in_as @owner

    patch inventory_path(@inventory),
          params: { inventory: { title: "Autosaved", lock_version: @inventory.lock_version } },
          as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "Autosaved", body["title"]
    assert_equal @inventory.reload.lock_version, body["version"]
  end

  test "a stale automatic saving is answered with a conflict" do
    sign_in_as @owner
    stale_version = @inventory.lock_version
    @inventory.update!(title: "Changed somewhere else")

    patch inventory_path(@inventory),
          params: { inventory: { title: "Autosaved", lock_version: stale_version } },
          as: :json

    assert_response :conflict
    assert_equal "conflict", response.parsed_body["error"]
  end

  test "the tags of an inventory are stored" do
    sign_in_as @owner

    patch inventory_path(@inventory), params: { inventory: { tag_list: "office, laptops" } }

    assert_equal %w[laptops office], @inventory.reload.tags.map(&:name).sort
  end
end
