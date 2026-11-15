# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# Signing in with an external provider (Google, Facebook, ...).
#
# The OmniAuth middleware puts the authentication hash into the request
# environment; the tests inject it the same way the middleware does.
class OmniauthControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  test "a visitor signs in with a provider and an account is created" do
    email = "google-#{SecureRandom.hex(6)}@example.test"

    get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: email) }

    assert_response :redirect
    user = User.find_by(email: email)
    assert_not_nil user
    assert_equal user.id, session_user_id
    assert_equal "google_oauth2", user.provider
    assert_not_nil user.uid
  end

  test "the account of a provider is reused" do
    email = "google-#{SecureRandom.hex(6)}@example.test"
    get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: email) }
    assert_not_nil session_user_id

    assert_no_difference -> { User.count } do
      get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: email) }
    end

    assert_equal session_user_id, User.find_by(email: email).id
  end

  test "an account that already exists with the same address is linked to the provider" do
    existing = create_user

    assert_no_difference -> { User.count } do
      get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: existing.email) }
    end

    existing.reload
    assert_equal "google_oauth2", existing.provider
    assert_equal existing.id, session_user_id
  end

  test "a provider that sends no address gets a placeholder one" do
    get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: nil) }

    user = User.find_by(provider: "google_oauth2", uid: "1234567890")
    assert_not_nil user
    assert_match(/users\.noreply\.invalid\z/, user.email)
    assert_equal user.id, session_user_id
  end

  test "the name of the provider is used when the account is created" do
    get "/auth/google_oauth2/callback", env: {
      "omniauth.auth" => omniauth_hash(email: "named-#{SecureRandom.hex(6)}@example.test", name: "Ada Lovelace")
    }

    user = User.find_by(name: "Ada Lovelace")
    assert_not_nil user
  end

  test "a blocked account cannot sign in with a provider" do
    user = create_user(blocked: true)

    get "/auth/google_oauth2/callback", env: { "omniauth.auth" => omniauth_hash(email: user.email) }

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
  end

  test "a callback without an authentication hash goes back to the sign in page" do
    get "/auth/google_oauth2/callback"

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_nil session_user_id
  end

  test "the failure page goes back to the sign in page" do
    get "/auth/failure"

    assert_response :redirect
    assert_redirected_to sign_in_path
    assert_not_empty flash[:alert]
  end

  private

  # An authentication hash, built the way the OmniAuth middleware builds it.
  def omniauth_hash(provider: "google_oauth2", uid: "1234567890", email: "oauth@example.test", name: "OAuth User")
    {
      "provider" => provider,
      "uid" => uid,
      "info" => { "email" => email, "name" => name },
      "extra" => { "raw_info" => { "picture" => "https://example.test/avatar.png" } }
    }
  end
end
