# frozen_string_literal: true

# OmniAuth configuration.
#
# The external providers are registered only when their credentials are
# present in the environment, so that the application boots on a machine
# that has no OAuth keys configured. Set the following variables to enable
# the buttons on the sign in page:
#
#   GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET
#   FACEBOOK_APP_ID       / FACEBOOK_APP_SECRET
#
# The request phase (`/auth/google`) has to be reached with POST when the
# omniauth-rails_csrf_protection gem is installed - that is the default in
# Rails 7 and later. The callback (`/auth/google/callback`) is called by the
# provider with a GET request and is handled by OmniauthController.
return unless defined?(OmniAuth)

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

Rails.application.config.middleware.use OmniAuth::Builder do
  google_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].to_s
  google_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].to_s

  if defined?(Omniauth::Strategies::GoogleOauth2) && google_client_id.present? && google_client_secret.present?
    provider :google_oauth2, google_client_id, google_client_secret,
             scope: "email,profile",
             prompt: "select_account"
  end

  facebook_app_id = ENV["FACEBOOK_APP_ID"].to_s
  facebook_app_secret = ENV["FACEBOOK_APP_SECRET"].to_s

  if defined?(Omniauth::Strategies::Facebook) && facebook_app_id.present? && facebook_app_secret.present?
    provider :facebook, facebook_app_id, facebook_app_secret,
             scope: "email",
             info_fields: "email,name,picture"
  end
end
