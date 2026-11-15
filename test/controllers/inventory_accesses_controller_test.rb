# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The access list of an inventory.
class InventoryAccessesControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers
  include DomainHelpers

  setup do
    @owner = create_user
    @guest = create_user
    @inventory = create_inventory(user: @owner)
  end

  test "a guest may not see the access list" do
    get inventory_accesses_path(@inventory)

    assert_redirected_to sign_in_path
  end

  test "a user with write access may not see the access list" do
    sign_in_as @guest

    get inventory_accesses_path(@inventory)

    assert_response :forbidden
    # The interface shows its own page for the requests that are refused.
    assert_match "Access denied", response.body
  end

  test "the owner sees the access list" do
    sign_in_as @owner

    get inventory_accesses_path(@inventory)

    assert_response :success
  end

  test "the owner adds a user by the email address" do
    sign_in_as @owner

    assert_difference("InventoryAccess.count") do
      post inventory_accesses_path(@inventory), params: { query: @guest.email }
    end

    assert_redirected_to inventory_accesses_path(@inventory)
  end

  test "the owner adds a user by the id of the autocompletion" do
    sign_in_as @owner

    assert_difference("InventoryAccess.count") do
      post inventory_accesses_path(@inventory), params: { user_id: @guest.id }
    end
  end

  test "a user that does not exist is reported" do
    sign_in_as @owner

    assert_no_difference("InventoryAccess.count") do
      post inventory_accesses_path(@inventory), params: { query: "nobody@example.test" }
    end

    assert_redirected_to inventory_accesses_path(@inventory)
  end

  test "the owner removes a user from the list" do
    access = InventoryAccess.create!(inventory: @inventory, user: @guest)
    sign_in_as @owner

    assert_difference("InventoryAccess.count", -1) do
      delete inventory_access_path(@inventory, access)
    end
  end

  test "the list is sorted by name or by email" do
    InventoryAccess.create!(inventory: @inventory, user: @guest)
    sign_in_as @owner

    get inventory_accesses_path(@inventory, sort: "email")
    assert_response :success

    get inventory_accesses_path(@inventory, sort: "name")
    assert_response :success
  end

  test "the autocompletion suggests the users" do
    sign_in_as @owner

    get suggestions_inventory_accesses_path(@inventory), params: { q: @guest.name[0, 3] }, as: :json

    assert_response :success
    ids = response.parsed_body.map { |user| user["id"] }
    assert_includes ids, @guest.id
    refute response.body.include?("password_digest")
  end

  test "the owner makes the inventory public" do
    sign_in_as @owner

    patch update_inventory_accesses_path(@inventory),
          params: { is_public: true, lock_version: @inventory.lock_version },
          as: :json

    assert_response :success
    assert @inventory.reload.is_public
  end

  test "a stale change of the visibility is answered with a conflict" do
    sign_in_as @owner
    stale_version = @inventory.lock_version
    @inventory.update!(title: "Changed somewhere else")

    patch update_inventory_accesses_path(@inventory),
          params: { is_public: true, lock_version: stale_version },
          as: :json

    assert_response :conflict
  end

  test "a guest may not make an inventory public" do
    patch update_inventory_accesses_path(@inventory), params: { is_public: true }

    assert_redirected_to sign_in_path
    refute @inventory.reload.is_public
  end
end
