# frozen_string_literal: true

# Resolves the local account behind an external identity.
#
# The OmniAuth middleware puts an authentication hash in the request
# environment after a successful round trip with the provider:
#
#   {
#     "provider" => "google_oauth2",
#     "uid"      => "1234567890",
#     "info"     => { "email" => "someone@example.com", "name" => "Someone", ... },
#     "extra"    => { "raw_info" => { "picture" => "https://..." } }
#   }
#
# This concern turns such a hash into a local User. The rules are:
#
#   1. an account that is already connected to that provider and uid is
#      reused;
#   2. otherwise an account with the same email is *linked*: the provider is
#      attached to the existing local account, so somebody who registered
#      with a password can later sign in with Google without ending up with
#      two accounts;
#   3. otherwise a new account is created.
#
# The concern only deals with the identity. Creating the session is the job
# of the Authentication concern.
module ProviderAuthentication
  extend ActiveSupport::Concern

  # Domain used to build a placeholder address when the provider does not
  # give us an email address. Those addresses can never receive mail.
  NOREPLY_EMAIL_DOMAIN = "users.noreply.invalid"

  # Outcome of resolving an authentication hash: either a user or a
  # human readable error.
  Resolution = Struct.new(:user, :error, :blocked) do
    def success?
      !user.nil?
    end
  end

  private

  # Resolves +auth+ into a local user.
  #
  # Returns a Resolution; the user is nil when the identity could not be
  # resolved, in which case +error+ explains why. The +blocked+ flag is set
  # when the account exists but has been blocked by an administrator.
  def resolve_provider_account(auth)
    provider = provider_value(auth, "provider").to_s
    uid = provider_value(auth, "uid").to_s

    return Resolution.new(nil, "The provider did not send an account identifier.") if provider.blank? || uid.blank?

    user = User.find_by(provider: provider, uid: uid)
    return Resolution.new(user, nil, user.blocked?) if user

    email = normalize_email(provider_info_value(auth, "email"))
    user = email.present? ? find_user_by_email(email) : nil

    return Resolution.new(nil, "This account is already connected to another provider.") if user && connected_to_other_provider?(user, provider)

    # A blocked account is never touched: it is not linked to the provider
    # and it is not signed in.
    return Resolution.new(user, nil, true) if user&.blocked?

    user = user ? link_provider(user, provider, uid, auth) : create_provider_user(provider, uid, email, auth)

    Resolution.new(user, nil, false)
  rescue ActiveRecord::RecordInvalid => e
    Resolution.new(nil, e.record.errors.full_messages.to_sentence)
  end

  # Attaches the external identity to an existing local account.
  def link_provider(user, provider, uid, auth)
    user.provider = provider
    user.uid = uid
    avatar = provider_avatar(auth)
    user.avatar_url = avatar if avatar.present?
    user.save!
    user
  end

  # Creates a brand new account for an external identity.
  def create_provider_user(provider, uid, email, auth)
    email = "#{provider}-#{uid}@#{NOREPLY_EMAIL_DOMAIN}" if email.blank?

    user = User.new(
      email: email,
      name: provider_name(auth, email),
      provider: provider,
      uid: uid,
      avatar_url: provider_avatar(auth)
    )

    # The account has no password of its own. A random one is set so that
    # the "password can't be blank" validation of `has_secure_password` is
    # satisfied; nobody can ever guess it.
    user.password = SecureRandom.hex(32) if user.respond_to?(:password=)

    user.save!
    user
  end

  # True when the account is already connected to a different provider.
  def connected_to_other_provider?(user, provider)
    user.provider.present? && user.provider != provider
  end

  # Display name of the external account, falling back to the local part of
  # the email address.
  def provider_name(auth, email)
    name = provider_info_value(auth, "name").to_s.strip
    name = provider_info_value(auth, "nickname").to_s.strip if name.blank?
    name = email.to_s.split("@").first.to_s if name.blank?
    name
  end

  # Avatar of the external account, if the provider sent one.
  def provider_avatar(auth)
    avatar = provider_info_value(auth, "image")
    avatar = provider_avatar_from_raw_info(auth) if avatar.blank?
    avatar.to_s.strip.presence
  end

  # Avatar of the external account, if the provider sent one.
  def provider_avatar(auth)
    avatar = provider_value(auth, "image")
    avatar = provider_avatar_from_raw_info(auth) if avatar.blank?
    avatar.to_s.strip.presence
  end

  # Some providers nest the picture inside `extra.raw_info`.
  def provider_avatar_from_raw_info(auth)
    extra = provider_value(auth, "extra")
    return nil unless extra.respond_to?(:[])

    raw = extra["raw_info"] || extra[:raw_info]
    return nil unless raw.respond_to?(:[])

    raw["picture"] || raw[:picture] || raw["avatar_url"] || raw[:avatar_url]
  end

  # Reads a key from an authentication hash, accepting both string and
  # symbol keys.
  def provider_value(auth, key)
    return nil if auth.nil?
    return nil unless auth.respond_to?(:[])

    value = auth[key]
    value = auth[key.to_s] if value.nil?
    value = auth[key.to_sym] if value.nil? && key.respond_to?(:to_sym)
    value
  end

  # Reads a key of the profile of the external account.
  #
  # OmniAuth puts the profile of the user under "info"; the top level of
  # the hash is used as a fallback so that a plain hash works as well.
  def provider_info_value(auth, key)
    info = provider_value(auth, "info")
    value = provider_value(info, key)
    value = provider_value(auth, key) if value.nil?
    value
  end

  # Normalises an email address the same way the registration form does.
  def normalize_email(value)
    email = value.to_s.strip.downcase
    email.presence
  end
end
