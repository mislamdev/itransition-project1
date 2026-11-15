# frozen_string_literal: true

# Registration with an email address and a password.
#
# A freshly registered user is signed in straight away.
class RegistrationsController < ApplicationController
  # GET /sign_up
  def new
    redirect_to root_path if user_signed_in?
  end

  # POST /sign_up
  def create
    user = User.new(registration_attributes)

    if user.save
      sign_in(user)
      redirect_to after_sign_in_path, notice: I18n.t("auth.welcome", default: "Welcome to the inventory!")
    else
      flash[:alert] = I18n.t("auth.registration_failed", default: "The account could not be created.")
      flash[:errors] = user.errors.full_messages
      redirect_to sign_up_location
    end
  end

  private

  # The submitted attributes.
  #
  # Both a flat form (email=...&password=...) and a nested one
  # (user[email]=...) are accepted.
  def registration_attributes
    source = registration_source
    attributes = source.permit(:email, :name, :password, :password_confirmation).to_h

    email = attributes["email"].to_s.strip.downcase
    attributes["email"] = email
    attributes["name"] = email.split("@").first if attributes["name"].to_s.strip.blank?

    attributes
  end

  def registration_source
    nested = params[:user]
    nested.respond_to?(:permit) ? nested : params
  end
end
