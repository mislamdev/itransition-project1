class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Authentication: who is signed in. Provides `current_user`,
  # `user_signed_in?` and `admin?` to the controllers and to the views.
  include Authentication

  # Authorization: what the signed in visitor is allowed to do. Provides
  # `can_edit_inventory?`, `can_write_items?` and friends.
  include Authorization

  # The interface language and the colour scheme of the visitor.
  around_action :switch_locale
  before_action :set_theme

  helper_method :current_locale, :current_theme, :available_locales

  private

  # The interface language of the visitor.
  #
  # A signed in user has chosen a language in the settings, where it is
  # stored on the user record.  Guests may change the language for the
  # current session (or with the `locale` parameter of the address).  The
  # language is restored after the request so that one visitor never changes
  # the language of another one.
  def switch_locale(&action)
    I18n.locale = current_locale
    yield
  ensure
    I18n.locale = I18n.default_locale
  end

  def current_locale
    candidate = params[:locale].presence || current_user&.locale.presence || session[:locale].presence
    return I18n.default_locale if candidate.blank?

    symbol = candidate.to_sym
    return I18n.default_locale unless I18n.available_locales.include?(symbol)

    # The choice of a guest is remembered for the session.
    session[:locale] = symbol if params[:locale].present?
    symbol
  end

  # The colour scheme of the visitor: "light" or "dark".
  def current_theme
    candidate = current_user&.theme.presence || session[:theme].presence
    candidate == "dark" ? "dark" : "light"
  end

  # Remembers the chosen theme for guests, whose choice cannot be stored on
  # a user record.
  def set_theme
    session[:theme] = current_theme if params[:theme].present? && session[:theme].blank?
  end

  def available_locales
    I18n.available_locales
  end
end
