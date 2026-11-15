# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# The validations of the account that matter for the authentication.
class UserTest < ActiveSupport::TestCase
  include AuthenticationHelpers

  test "the email address is required" do
    user = User.new(password: "a good password")

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "the email address is unique" do
    existing = create_user

    user = User.new(email: existing.email, password: "a good password")

    assert_not user.valid?
    assert_includes user.errors[:email].join, "taken"
  end

  test "a local account needs a password" do
    user = User.new(email: "without-password@example.test")

    assert_not user.valid?
  end

  test "the password is stored encrypted" do
    user = create_user

    assert_not_equal DEFAULT_PASSWORD, user.password_digest
    assert user.authenticate(DEFAULT_PASSWORD)
    assert_not user.authenticate("something else")
  end

  test "the password confirmation is checked" do
    user = User.new(
      email: "confirmation@example.test",
      password: "a good password",
      password_confirmation: "another password"
    )

    assert_not user.valid?
  end

  test "an account of a provider needs no password" do
    user = User.new(email: "provider@example.test", provider: "google_oauth2", uid: "123456")

    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "the session version starts at zero" do
    assert_equal 0, create_user.session_version
  end

  test "an administrator and a blocked account are plain booleans" do
    admin = create_user(admin: true, blocked: true)

    assert admin.admin?
    assert admin.blocked?
  end
end
