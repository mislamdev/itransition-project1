# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# Signing in and out with an email address and a password.
class SessionsControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  test "a user signs in with the right email address and password" do
    user = create_user

    post sign_in_path, params: { email: user.email, password: DEFAULT_PASSWORD }

    assert_response :redirect
    assert_equal user.id, session_user_id
    assert_no_match %r{/sign_in}, response.location
  end

  test "the email address is matched ignoring its case" do
    user = create_user(email: "Mixed.Case@example.test")

    post sign_in_path, params: { email: "MIXED.CASE@EXAMPLE.TEST", password: DEFAULT_PASSWORD }

    assert_equal user.id, session_user_id
  end

  test "a wrong password is refused" do
    user = create_user

    post sign_in_path, params: { email: user.email, password: "not the password" }

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
    assert_not_empty flash[:alert]
  end

  test "an unknown email address is refused" do
    post sign_in_path, params: { email: "nobody@example.test", password: DEFAULT_PASSWORD }

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
    assert_not_empty flash[:alert]
  end

  test "a blocked user cannot sign in" do
    user = create_user(blocked: true)

    post sign_in_path, params: { email: user.email, password: DEFAULT_PASSWORD }

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
  end

  test "signing out ends the session" do
    user = create_user
    sign_in_as(user)
    assert_equal user.id, session_user_id

    delete sign_out_path

    assert_response :redirect
    assert_nil session_user_id
  end

  test "the session is not kept when the user signs out and in again" do
    user = create_user
    sign_in_as(user)

    delete sign_out_path
    post sign_in_path, params: { email: user.email, password: DEFAULT_PASSWORD }

    assert_equal user.id, session_user_id
  end

  test "a signed in user is sent back to the page they came from" do
    user = create_user

    # A page that requires an account stores its location in the session.
    get protected_path
    assert_response :redirect

    post sign_in_path, params: { email: user.email, password: DEFAULT_PASSWORD }

    assert_response :redirect
    assert_equal user.id, session_user_id
    assert_no_match %r{/sign_in}, response.location
  end

  test "a signed in user is not offered the sign in page again" do
    user = create_user
    sign_in_as(user)

    get sign_in_path

    assert_response :redirect
    assert_no_match %r{/sign_in}, response.location
  end
end
