# A registered account.
#
# An account is created either with an email address and a password or
# through an external provider (Google, Facebook).  Provider accounts carry
# the provider name and the provider's user id; they may or may not have a
# password digest, which is why the password validations are custom.
class User < ApplicationRecord
  # The password is stored as a digest.  The validations that come with
  # `has_secure_password` are switched off, because a provider account may
  # be created without a password; the rules below replace them:
  #
  #   * a password that is given has to be long enough;
  #   * a local account (one that was not created by a provider) needs a
  #     password;
  #   * the confirmation has to match the password.
  has_secure_password validations: false

  has_many :inventories, dependent: :destroy
  has_many :created_items, class_name: "Item", foreign_key: :created_by_id, dependent: :nullify
  has_many :inventory_accesses, dependent: :destroy
  has_many :accessible_inventories, through: :inventory_accesses, source: :inventory
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 120 }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :password, presence: true, if: -> { !oauth? && (new_record? || password.present?) }
  validates :password, confirmation: true, if: -> { password.present? && password_confirmation.present? }

  scope :active, -> { where(blocked: false) }
  scope :by_name, -> { order(Arel.sql("LOWER(users.name) ASC, LOWER(users.email) ASC")) }
  scope :by_email, -> { order(Arel.sql("LOWER(users.email) ASC")) }

  # True when the account was created through an external provider.
  def oauth?
    provider.present?
  end

  # Active Record already provides `admin?` and `blocked?` for boolean
  # columns; they are repeated here so that the intention is obvious at the
  # call site.
  def admin?
    self[:admin]
  end

  def blocked?
    self[:blocked]
  end

  # Name shown in the interface.  Never empty, even for accounts that were
  # created without a name.
  def display_name
    name.presence || email.to_s.split("@").first
  end

  # Invalidates every session of this user (used when an administrator
  # blocks the account).
  def invalidate_sessions!
    update_column(:session_version, session_version + 1)
  end

  # The password digest and the session version never leave the server, not
  # even when a user is serialized into JSON by accident.
  def as_json(options = nil)
    options = (options || {}).dup
    except = (Array(options[:except]) + %i[password_digest session_version]).uniq
    super(options.merge(except: except))
  end
end
