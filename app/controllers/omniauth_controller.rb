# frozen_string_literal: true

# Sign in with an external provider (Google, Facebook, ...).
#
# The OmniAuth middleware performs the round trip with the provider and puts
# the authentication hash into the request environment. This controller turns
# that hash into a local account and starts a session.
#
# The providers are configured in config/initializers/omniauth.rb; they are
# only registered when their credentials are present in the environment.
class OmniauthController < ApplicationController
  include ProviderAuthentication

  # GET|POST /auth/:provider/callback
  def callback
    resolution = resolve_provider_account(auth_hash)

    unless resolution.success?
      flash[:alert] = resolution.error || I18n.t("auth.oauth_failed", default: "Could not sign you in with that provider.")
      return redirect_to sign_in_location
    end

    user = resolution.user

    if user.blocked?
      flash[:alert] = I18n.t("auth.account_blocked", default: "This account has been blocked.")
      return redirect_to sign_in_location
    end

    sign_in(user)
    redirect_to after_sign_in_path, notice: signed_in_notice(user)
  end

  # GET /auth/failure
  #
  # Reached when the provider refuses the request or the user denies the
  # authorisation.
  def failure
    flash[:alert] = I18n.t("auth.oauth_failed", default: "Could not sign you in with that provider.")
    redirect_to sign_in_location
  end

  private

  # The authentication hash built by the OmniAuth middleware.
  #
  # Only server side data is accepted here: the hash is never taken from the
  # parameters, otherwise anybody could log in as somebody else by crafting
  # a request. The copy kept in the session is deleted right away so that it
  # cannot be replayed.
  def auth_hash
    hash = request.env["omniauth.auth"]
    hash ||= session.delete("omniauth.auth")
    hash
  end

  def signed_in_notice(user)
    label = provider_label(auth_hash)
    if label.present?
      I18n.t("auth.signed_in_with", default: "Signed in with %{provider}.") % { provider: label }
    else
      I18n.t("auth.signed_in", default: "Signed in successfully.")
    end
  end

  # Human readable name of the provider that signed the user in.
  def provider_label(hash)
    provider = provider_value(hash, "provider").to_s
    PROVIDER_LABELS[provider] || provider.humanize.presence
  end

  PROVIDER_LABELS = {
    "google_oauth2" => "Google",
    "google" => "Google",
    "facebook" => "Facebook"
  }.freeze
end
