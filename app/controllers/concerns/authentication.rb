# frozen_string_literal: true

# Session handling shared by every controller.
#
# The application supports two ways of signing in:
#
#   * email + password (see RegistrationsController / SessionsController);
#   * an external provider such as Google or Facebook
#     (see OmniauthController).
#
# Both end up calling {#sign_in}, so the session format is identical
# regardless of how the user authenticated.
#
# The concern is included in ApplicationController and exposes three helpers
# to the views: `current_user`, `user_signed_in?` and `admin?`.
module Authentication
  extend ActiveSupport::Concern

  # Session keys. The version key is optional: it is only used when the
  # `users` table has a `session_version` column, which lets an administrator
  # invalidate every session of a user at once (used when blocking a user).
  SESSION_USER_KEY = :user_id
  SESSION_VERSION_KEY = :user_session_version

  # The colour themes of the interface.
  THEMES = %w[light dark].freeze

  included do
    helper_method :current_user, :user_signed_in?, :admin?, :current_locale, :current_theme

    # The language of the interface is chosen for every request.
    before_action :set_interface_locale
  end

  # The user behind the current request, or nil when the visitor is
  # anonymous. Memoised so that the database is queried at most once per
  # request.
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = user_from_session
  end

  def user_signed_in?
    current_user.present?
  end

  # Administrators have full access: they may act as the owner of every
  # inventory (see the Authorization concern).
  def admin?
    user_signed_in? && current_user.admin?
  end

  # The language of the interface.
  #
  # The choice of a signed in user is stored on the account; a visitor
  # without an account keeps it in the session, so that the choice also
  # works for a guest.
  def current_locale
    locale = (current_user&.locale || session[:locale]).to_s
    supported_locales.include?(locale) ? locale : I18n.default_locale.to_s
  end

  # The colour theme of the interface.
  def current_theme
    theme = (current_user&.theme || session[:theme]).to_s
    THEMES.include?(theme) ? theme : THEMES.first
  end

  # Starts a session for +user+.
  #
  # The session is reset first so that a session id captured before the
  # login (session fixation) cannot be reused afterwards. The page the
  # visitor wanted to reach is kept across the reset.
  def sign_in(user)
    return_to = session[:return_to]

    reset_session
    session[SESSION_USER_KEY] = user.id
    session[SESSION_VERSION_KEY] = user.session_version if user.respond_to?(:session_version)
    session[:return_to] = return_to if return_to.present?

    @current_user = user
  end

  # Ends the current session.
  def sign_out
    reset_session
    @current_user = nil
  end

  # Finds a user by email address, ignoring the case of the address.
  #
  # The exact match comes first so that the unique index on the email
  # address is used; the slower comparison is only needed for accounts that
  # were created before the addresses were normalised.
  def find_user_by_email(email)
    email = email.to_s.strip.downcase
    return nil if email.blank?

    user = User.find_by(email: email)
    return user if user

    User.where("LOWER(users.email) = ?", email).first
  end

  private

  # Applies the language of the visitor to the request.
  def set_interface_locale
    I18n.locale = current_locale
  end

  # The languages of the interface, as configured in config/application.rb.
  def supported_locales
    I18n.available_locales.map(&:to_s)
  end

  # Reads the user referenced by the session.
  #
  # Returns nil - and forgets the session - when the user no longer exists,
  # has been blocked by an administrator, or when the session has been
  # invalidated through `session_version`.
  def user_from_session
    user_id = session[SESSION_USER_KEY]
    return nil if user_id.blank?

    user = User.find_by(id: user_id)
    return forget_session if user.nil?

    # A blocked user is signed out immediately.
    return forget_session if user.blocked?

    # The session was issued for an older version of the account (the user
    # was blocked, or the session was invalidated some other way).
    if user.respond_to?(:session_version) &&
       session[SESSION_VERSION_KEY].to_i != user.session_version.to_i
      return forget_session
    end

    user
  end

  # Drops every key of the session and returns nil so that it can be used
  # inline (see #user_from_session).
  def forget_session
    reset_session
    nil
  end

  # --- filters ---------------------------------------------------------

  # Filter for controllers that require a signed in user.
  #
  # Returns true when the request may continue, false when a redirect has
  # been issued.
  def require_authentication
    return true if user_signed_in?

    store_return_location
    redirect_to sign_in_location, alert: I18n.t("auth.sign_in_required", default: "Please sign in to continue.")
    false
  end

  # Filter for controllers that require an administrator.
  def require_admin
    return false unless require_authentication
    return true if admin?

    redirect_to root_path, alert: I18n.t("auth.admin_required", default: "You are not allowed to access that page.")
    false
  end

  # Remembers the page the visitor wanted to reach so that the login form
  # can send them back to it.
  def store_return_location
    return unless request.get? || request.head?

    session[:return_to] = request.fullpath
  end

  # The page to redirect to after a successful sign in.
  #
  # Only local paths are accepted: a stored location coming from the
  # session is never allowed to point at another host.
  def after_sign_in_path
    location = session.delete(:return_to)
    return root_path if location.blank?
    return location if local_path?(location)

    root_path
  end

  # True when +path+ is a path on this host (and not an absolute URL).
  def local_path?(path)
    path.to_s.start_with?("/") && !path.to_s.start_with?("//")
  end

  # --- locations -------------------------------------------------------

  # Path of the sign in page.
  #
  # The named route helper is used when it exists; the literal path is used
  # as a fallback so that the authentication filters never fail with a
  # NameError when the route has not been added yet.
  def sign_in_location
    route_location(:sign_in_path, "/sign_in")
  end

  # Path of the sign up page.
  def sign_up_location
    route_location(:sign_up_path, "/sign_up")
  end

  # Path of the admin user list.
  def admin_users_location
    route_location(:admin_users_path, "/admin/users")
  end

  def route_location(helper_name, fallback)
    helpers = Rails.application.routes.url_helpers
    helpers.respond_to?(helper_name) ? helpers.public_send(helper_name) : fallback
  end
end
