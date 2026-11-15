# frozen_string_literal: true

# Signing in and out with an email address and a password.
#
# The session itself is managed by the Authentication concern, this
# controller only reads the credentials and decides where to go next.
class SessionsController < ApplicationController
  # GET /sign_in
  def new
    redirect_to root_path if user_signed_in?
  end

  # POST /sign_in
  def create
    user = authenticate_user(credentials[:email], credentials[:password])

    if user.nil?
      flash[:alert] = I18n.t("auth.invalid_credentials", default: "Invalid email or password.")
      return redirect_to sign_in_location
    end

    if user.blocked?
      flash[:alert] = I18n.t("auth.account_blocked", default: "This account has been blocked.")
      return redirect_to sign_in_location
    end

    sign_in(user)
    redirect_to after_sign_in_path, notice: I18n.t("auth.signed_in", default: "Signed in successfully.")
  end

  # DELETE /sign_out
  def destroy
    sign_out
    redirect_to root_path, notice: I18n.t("auth.signed_out", default: "Signed out.")
  end

  private

  # Finds the user and checks the password.
  #
  # Returns nil when either the account does not exist or the password does
  # not match.
  def authenticate_user(email, password)
    user = find_user_by_email(email)

    if user.nil?
      # Spend roughly the same amount of time as a real comparison would
      # take, so that the answer does not reveal whether the account exists.
      BCrypt::Password.create(password.to_s) if defined?(BCrypt)
      return nil
    end

    return nil unless user.respond_to?(:authenticate)
    return nil unless user.authenticate(password.to_s)

    user
  end

  # The submitted credentials. Both a flat form (email=...&password=...) and
  # a nested one (user[email]=...) are accepted.
  def credentials
    source = params[:session]
    source = params unless source.respond_to?(:[])
    {
      email: source[:email],
      password: source[:password]
    }
  end

  def normalize_email(value)
    value.to_s.strip.downcase
  end
end
