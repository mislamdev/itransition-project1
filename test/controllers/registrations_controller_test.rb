# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# Creating an account with an email address and a password.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  test "a visitor creates an account and is signed in straight away" do
    email = "newcomer-#{SecureRandom.hex(6)}@example.test"

    post sign_up_path, params: {
      email: email,
      name: "New Comer",
      password: DEFAULT_PASSWORD,
      password_confirmation: DEFAULT_PASSWORD
    }

    assert_response :redirect
    assert_equal email, User.find_by(email: email)&.email
    assert_equal User.find_by(email: email).id, session_user_id
  end

  test "the email address is stored in lower case" do
    email = "MiXeD-#{SecureRandom.hex(6)}@Example.TEST"

    post sign_up_path, params: {
      email: email,
      password: DEFAULT_PASSWORD,
      password_confirmation: DEFAULT_PASSWORD
    }

    assert_equal email.downcase, User.find_by(email: email.downcase)&.email
  end

  test "the name of the account defaults to the name of the mailbox" do
    email = "nameless-#{SecureRandom.hex(6)}@example.test"

    post sign_up_path, params: {
      email: email,
      password: DEFAULT_PASSWORD,
      password_confirmation: DEFAULT_PASSWORD
    }

    assert_equal email.split("@").first, User.find_by(email: email)&.name
  end

  test "an account without an email address is not created" do
    assert_no_difference -> { User.count } do
      post sign_up_path, params: { email: "", password: DEFAULT_PASSWORD }
    end

    assert_response :redirect
    assert_redirected_to sign_up_path
    assert_nil session_user_id
  end

  test "an account without a password is not created" do
    assert_no_difference -> { User.count } do
      post sign_up_path, params: { email: "nopassword-#{SecureRandom.hex(6)}@example.test", password: "" }
    end

    assert_response :redirect
    assert_redirected_to sign_up_path
    assert_nil session_user_id
  end

  test "an address that is already taken is refused" do
    existing = create_user

    assert_no_difference -> { User.count } do
      post sign_up_path, params: {
        email: existing.email,
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD
      }
    end

    assert_response :redirect
    assert_redirected_to sign_up_path
    assert_nil session_user_id
  end

  test "a signed in visitor is not offered the registration page again" do
    sign_in_as(create_user)

    get sign_up_path

    assert_response :redirect
    assert_no_match %r{/sign_up}, response.location
  end
end
