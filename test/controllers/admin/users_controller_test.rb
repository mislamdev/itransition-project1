# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# The administration of the user accounts.
class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  # --- who may reach the administration -------------------------------

  test "an anonymous visitor is sent to the sign in page" do
    get admin_users_path

    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  test "an ordinary user is sent away from the administration" do
    sign_in_as(create_user)

    get admin_users_path

    assert_response :redirect
    assert_no_match %r{/admin/users}, response.location
  end

  test "an ordinary user may not change an account" do
    sign_in_as(create_user)
    victim = create_user

    patch admin_user_path(victim), params: { admin: "1" }

    assert_response :redirect
    assert_no_match %r{/admin/users}, response.location
    assert_not victim.reload.admin
  end

  test "an administrator sees the list of the accounts" do
    skip "the view of the administration page belongs to the frontend" unless admin_view_exists?

    sign_in_as(create_admin)
    create_user(name: "Somebody")

    get admin_users_path

    assert_response :success
  end

  # --- the administrator role ------------------------------------------

  test "an administrator gives the role to an account" do
    sign_in_as(create_admin)
    user = create_user

    patch admin_user_path(user), params: { admin: "1" }

    assert_response :redirect
    assert user.reload.admin
  end

  test "an administrator takes the role away from an account" do
    sign_in_as(create_admin)
    user = create_user(admin: true)

    patch admin_user_path(user), params: { admin: "0" }

    assert_response :redirect
    assert_not user.reload.admin
  end

  test "the role may also be given with the role parameter" do
    sign_in_as(create_admin)
    user = create_user

    patch admin_user_path(user), params: { role: "admin" }

    assert user.reload.admin
  end

  # The requirement of the project: an administrator may remove the
  # administrator access from himself.
  test "an administrator takes the role away from himself" do
    admin = create_admin
    sign_in_as(admin)

    patch admin_user_path(admin), params: { admin: "0" }

    assert_response :redirect
    assert_not admin.reload.admin
  end

  test "the access is revoked at once when an administrator demotes himself" do
    admin = create_admin
    sign_in_as(admin)

    patch admin_user_path(admin), params: { admin: "0" }

    # The account is still signed in, but it is an ordinary one now.
    assert_equal admin.id, session_user_id

    get admin_users_path
    assert_response :redirect
    assert_no_match %r{/admin/users}, response.location
  end

  test "an administrator who demoted himself may sign in again as an ordinary user" do
    admin = create_admin
    sign_in_as(admin)
    patch admin_user_path(admin), params: { admin: "0" }

    delete sign_out_path
    post sign_in_path, params: { email: admin.email, password: DEFAULT_PASSWORD }

    assert_equal admin.id, session_user_id
    get admin_users_path
    assert_response :redirect
    assert_no_match %r{/admin/users}, response.location
  end

  # --- blocking ---------------------------------------------------------

  test "an administrator blocks an account" do
    sign_in_as(create_admin)
    user = create_user

    patch admin_user_path(user), params: { blocked: "1" }

    assert_response :redirect
    assert user.reload.blocked
  end

  test "an administrator unblocks an account" do
    sign_in_as(create_admin)
    user = create_user(blocked: true)

    patch admin_user_path(user), params: { blocked: "0" }

    assert_response :redirect
    assert_not user.reload.blocked
  end

  test "a blocked account is signed out immediately" do
    user = create_user
    sign_in_as(user)

    # The administrator blocks the account from another browser.
    admin = create_admin
    admin_session = open_session
    admin_session.post sign_in_path, params: { email: admin.email, password: DEFAULT_PASSWORD }
    admin_session.patch admin_user_path(user), params: { blocked: "1" }

    # The account is no longer signed in.
    get protected_path

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
  end

  test "a blocked account may sign in again once it is unblocked" do
    user = create_user
    sign_in_as(user)

    admin = create_admin
    admin_session = open_session
    admin_session.post sign_in_path, params: { email: admin.email, password: DEFAULT_PASSWORD }
    admin_session.patch admin_user_path(user), params: { blocked: "1" }

    admin_session.patch admin_user_path(user), params: { blocked: "0" }

    delete sign_out_path
    post sign_in_path, params: { email: user.email, password: DEFAULT_PASSWORD }

    assert_equal user.id, session_user_id
  end

  # --- deleting ---------------------------------------------------------

  test "an administrator deletes an account" do
    sign_in_as(create_admin)
    user = create_user

    assert_difference -> { User.count }, -1 do
      delete admin_user_path(user)
    end

    assert_response :redirect
    assert_nil User.find_by(id: user.id)
  end

  test "an ordinary user may not delete an account" do
    sign_in_as(create_user)
    victim = create_user

    assert_no_difference -> { User.count } do
      delete admin_user_path(victim)
    end

    assert_response :redirect
    assert_not_nil User.find_by(id: victim.id)
  end

  private

  # The view of the administration page is written by the frontend.
  def admin_view_exists?
    Rails.root.join("app/views/admin/users/index.html.erb").exist?
  end
end
