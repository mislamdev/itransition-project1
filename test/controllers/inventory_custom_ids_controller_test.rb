# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The tab with the custom inventory numbers.
class InventoryCustomIdsControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers
  include DomainHelpers

  setup do
    @owner = create_user
    @inventory = create_inventory_with_format(user: @owner)
  end

  test "the owner sees the format of the inventory" do
    sign_in_as @owner

    get edit_inventory_custom_id_path(@inventory)

    assert_response :success
  end

  test "a guest may not see the format" do
    get edit_inventory_custom_id_path(@inventory)

    assert_redirected_to sign_in_path
  end

  test "a user with write access may not see the format" do
    sign_in_as create_user

    get edit_inventory_custom_id_path(@inventory)

    assert_response :forbidden
  end

  test "the preview shows an example of the saved format" do
    sign_in_as @owner

    get preview_inventory_custom_id_path(@inventory), as: :json

    assert_response :success
    assert_match(/\AINV-\d+-\d{6}\z/, response.parsed_body["preview"])
    assert_equal "INV-{sequence}-{random_6}", response.parsed_body["format"]
  end

  test "the preview shows an example of a format that is not saved yet" do
    sign_in_as @owner

    post preview_inventory_custom_id_path(@inventory),
         params: { elements: [{ kind: "fixed", text: "QA-", options: {} }, { kind: "random_9", options: {} }] },
         as: :json

    assert_response :success
    assert_match(/\AQA-\d{9}\z/, response.parsed_body["preview"])
    assert_equal "QA-{random_9}", response.parsed_body["format"]
  end

  test "the owner saves a new format" do
    sign_in_as @owner

    patch inventory_custom_id_path(@inventory),
          params: { elements: [{ kind: "fixed", text: "QA-", options: {} }, { kind: "random_9", options: {} }] }

    assert_redirected_to edit_inventory_custom_id_path(@inventory)

    elements = @inventory.reload.id_format_elements.ordered
    assert_equal %w[fixed random_9], elements.map(&:kind)
    assert_equal "QA-{random_9}", @inventory.custom_id_format
  end

  test "the saved format is used for the new items" do
    sign_in_as @owner

    patch inventory_custom_id_path(@inventory),
          params: { elements: [{ kind: "fixed", text: "QA-", options: {} }, { kind: "random_9", options: {} }] }

    post inventory_items_path(@inventory), params: { item: {} }

    assert_match(/\AQA-\d{9}\z/, Item.order(:id).last.custom_id)
  end

  test "a guest may not save a format" do
    patch inventory_custom_id_path(@inventory),
          params: { elements: [{ kind: "fixed", text: "QA-", options: {} }] }

    assert_redirected_to sign_in_path
    assert_equal 4, @inventory.reload.id_format_elements.count
  end
end
