# frozen_string_literal: true

# Personal settings of the visitor.
#
# The language and the colour theme are stored on the account, so that the
# choice follows the user to every browser. A visitor without an account may
# choose them as well: the choice is then kept in the session and lasts as
# long as the browser session.
class SettingsController < ApplicationController
  # Changing the password needs an account; choosing the language and the
  # theme does not.
  before_action :require_authentication, only: :update_password

  # POST|PATCH /settings
  def update
    attributes = settings_attributes

    # The language and the theme are kept in the session as well, so that
    # they work for a visitor without an account and are applied at once.
    guest_attributes = attributes.slice(:locale, :theme)
    guest_attributes.each { |key, value| session[key] = value }

    account_attributes = user_signed_in? ? attributes : {}

    if account_attributes.empty? && guest_attributes.empty?
      return redirect_back fallback_location: root_path,
                            notice: I18n.t("settings.nothing_to_update", default: "Nothing to update.")
    end

    current_user.update!(account_attributes) if account_attributes.present?

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, notice: I18n.t("settings.saved", default: "Settings saved.") }
      format.json { render json: { locale: current_locale, theme: current_theme } }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html do
        flash[:alert] = e.record.errors.full_messages.to_sentence
        redirect_back fallback_location: root_path
      end
      format.json { render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity }
    end
  end

  # PATCH /settings/password
  #
  # Changes the password of the signed in user.
  def update_password
    user = current_user

    unless user.respond_to?(:authenticate) && user.authenticate(password_params[:current_password].to_s)
      flash[:alert] = I18n.t("settings.wrong_password", default: "The current password is not correct.")
      return redirect_back fallback_location: root_path
    end

    user.password = password_params[:password].to_s
    user.password_confirmation = password_params[:password_confirmation].to_s

    if user.save
      redirect_back fallback_location: root_path, notice: I18n.t("settings.password_changed", default: "Password changed.")
    else
      flash[:alert] = user.errors.full_messages.to_sentence
      redirect_back fallback_location: root_path
    end
  end

  private

  # The settings that may be changed. Only known values are accepted, so a
  # hand crafted request cannot put an arbitrary string into the database.
  def settings_attributes
    attributes = {}
    source = settings_source

    locale = source[:locale].to_s.strip.downcase
    attributes[:locale] = locale if supported_locales.include?(locale)

    theme = source[:theme].to_s.strip.downcase
    attributes[:theme] = theme if Authentication::THEMES.include?(theme)

    name = source[:name].to_s.strip
    attributes[:name] = name if name.present? && name.length <= 120

    attributes
  end

  # The submitted settings. Both a flat form (theme=dark) and a nested one
  # (settings[theme]=dark) are accepted.
  def settings_source
    nested = params[:settings]
    nested.is_a?(ActionController::Parameters) ? nested : params
  end

  # The submitted password. The parameters of the form are nested under
  # `password`; when the form is flat the top level parameters are used.
  def password_params
    source = params[:password]
    source.is_a?(ActionController::Parameters) ? source : params
  end
end
