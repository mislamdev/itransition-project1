# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")

# The personal settings: language, theme and password.
class SettingsControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  test "a user changes the theme" do
    user = create_user
    sign_in_as(user)

    post settings_path, params: { theme: "dark" }

    assert_response :redirect
    assert_equal "dark", user.reload.theme
  end

  test "a user changes the language" do
    skip "the interface has only one language" if other_locale.nil?
    user = create_user
    sign_in_as(user)

    post settings_path, params: { locale: other_locale }

    assert_response :redirect
    assert_equal other_locale, user.reload.locale
  end

  test "a language that the interface does not know is ignored" do
    user = create_user
    sign_in_as(user)

    post settings_path, params: { locale: "xx" }

    assert_equal "en", user.reload.locale
  end

  test "an unknown theme is ignored" do
    user = create_user
    sign_in_as(user)

    post settings_path, params: { theme: "neon" }

    assert_equal "light", user.reload.theme
  end

  test "a user changes their own name" do
    user = create_user
    sign_in_as(user)

    post settings_path, params: { name: "Ada Lovelace" }

    assert_equal "Ada Lovelace", user.reload.name
  end

  # --- a visitor without an account -------------------------------------

  test "a visitor without an account chooses the theme" do
    post settings_path, params: { theme: "dark" }

    assert_response :redirect
    assert_equal "dark", request.session[:theme]
  end

  test "a visitor without an account chooses the language" do
    skip "the interface has only one language" if other_locale.nil?

    post settings_path, params: { locale: other_locale }

    assert_response :redirect
    assert_equal other_locale, request.session[:locale]
  end

  test "the chosen theme is used by the following requests" do
    post settings_path, params: { theme: "dark" }

    assert_equal "dark", request.session[:theme]
  end

  test "a visitor without an account cannot change the password" do
    patch settings_password_path, params: {
      current_password: DEFAULT_PASSWORD,
      password: "another very good password",
      password_confirmation: "another very good password"
    }

    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  # --- the password -----------------------------------------------------

  test "the password is changed with the right current password" do
    user = create_user
    sign_in_as(user)
    new_password = "another very good password"

    patch settings_password_path, params: {
      current_password: DEFAULT_PASSWORD,
      password: new_password,
      password_confirmation: new_password
    }

    assert_response :redirect
    assert user.reload.authenticate(new_password)
  end

  test "the password is not changed with a wrong current password" do
    user = create_user
    sign_in_as(user)

    patch settings_password_path, params: {
      current_password: "not the password",
      password: "another very good password",
      password_confirmation: "another very good password"
    }

    assert_response :redirect
    assert user.reload.authenticate(DEFAULT_PASSWORD)
  end

  test "the password is changed with the parameters of a nested form" do
    user = create_user
    sign_in_as(user)
    new_password = "another very good password"

    patch settings_password_path, params: {
      password: {
        current_password: DEFAULT_PASSWORD,
        password: new_password,
        password_confirmation: new_password
      }
    }

    assert_response :redirect
    assert user.reload.authenticate(new_password)
  end

  private

  # The second language of the interface, whatever it is.
  def other_locale
    (I18n.available_locales.map(&:to_s) - ["en"]).first
  end
end
