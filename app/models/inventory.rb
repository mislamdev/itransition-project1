# An inventory: a set of fields plus the items filled in with them.
#
# Permissions (see the Authorization concern for the session side of it):
#
#   * everybody may read an inventory and its items;
#   * the owner and the administrators may change everything;
#   * everybody may add items when the inventory is public or when the user
#     was granted write access explicitly.
class Inventory < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  has_many :items, dependent: :destroy
  has_many :fields, -> { order(:position, :id) }, dependent: :destroy
  has_many :field_values, through: :fields
  has_many :inventory_accesses, dependent: :destroy
  has_many :accessible_users, through: :inventory_accesses, source: :user
  has_many :comments, dependent: :destroy
  has_many :inventory_tags, dependent: :destroy
  has_many :tags, through: :inventory_tags
  has_many :id_format_elements, -> { order(:position, :id) }, dependent: :destroy
  has_many :inventory_sequences, dependent: :destroy

  accepts_nested_attributes_for :id_format_elements, allow_destroy: true
  accepts_nested_attributes_for :fields, allow_destroy: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 20_000 }

  scope :latest, -> { order(created_at: :desc, id: :desc) }
  # The most popular inventories, measured by the number of items.  The count
  # comes from a counter cache, so the list never runs a query per row.
  scope :popular, -> { order(items_count: :desc, created_at: :desc) }

  # The owner of the inventory.  `owner` is the word used in the interface,
  # `user` is the column name.
  alias_attribute :owner_id, :user_id

  def owner
    user
  end

  def owner=(new_owner)
    self.user = new_owner
  end

  # --- permissions ------------------------------------------------------

  # The owner and the administrators may edit the inventory settings, its
  # fields, its access list and its custom id format.
  def editable_by?(user)
    return false if user.blank?

    user.admin? || user_id == user.id
  end

  # The owner, the administrators, everybody when the inventory is public and
  # the users that were granted write access explicitly.
  def writable_by?(user)
    return false if user.blank?
    return true if user.admin? || user_id == user.id
    return true if is_public?

    inventory_accesses.exists?(user_id: user.id)
  end

  # Reading is public: every inventory and every item can be read by
  # everybody, anonymous visitors included.
  def accessible_by?(_user = nil)
    true
  end

  # `public` is a reserved-ish word in Ruby, `is_public` is the column, so
  # both spellings are offered to the views.
  def public?
    is_public?
  end

  def public
    is_public
  end

  # --- tags -------------------------------------------------------------

  # The tags of the inventory as a comma separated list.
  def tag_list
    tags.map(&:name).join(", ")
  end

  # Assigns the tags from a comma separated list.  Unknown tags are created;
  # tags that are no longer used are removed from this inventory (the tag
  # record itself is kept, other inventories may still use it).
  def tag_list=(value)
    names = value.to_s.split(",").map { |name| name.strip }.reject(&:blank?).uniq(&:downcase)
    self.tags = names.map { |name| Tag.find_or_create_by_name(name) }
  end

  # --- custom inventory numbers -----------------------------------------

  # The renderer that knows how to build and how to validate the custom ids
  # of this inventory.  The very same object is used for the preview shown
  # in the interface and for the ids that are actually stored.
  def custom_id_formatter
    CustomId::Formatter.new(id_format_elements.to_a)
  end

  # A human readable description of the format, e.g. "INV-{sequence}-{random_6}".
  def custom_id_format
    custom_id_formatter.format_string
  end

  # --- statistics --------------------------------------------------------

  # Number of items, kept up to date by a counter cache.
  def items_count
    self[:items_count]
  end
end
