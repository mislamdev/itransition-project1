# A single entry of an inventory.
#
# Beside the values of the custom fields an item carries a *custom id*: an
# identifier that is unique within its inventory and generated from the
# format the owner defined.  The uniqueness is enforced by the database
# (unique index on inventory_id + custom_id).
class Item < ApplicationRecord
  belongs_to :inventory, counter_cache: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :field_values, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liked_by_users, through: :likes, source: :user

  accepts_nested_attributes_for :field_values, allow_destroy: true

  validates :custom_id, presence: true, uniqueness: { scope: :inventory_id }
  validate :custom_id_matches_the_inventory_format

  after_save :refresh_search_text

  scope :ordered, -> { order(:created_at, :id) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # --- permissions ------------------------------------------------------

  # Items follow the permissions of their inventory.
  def editable_by?(user)
    return false if user.blank?

    inventory.present? && inventory.writable_by?(user)
  end

  # --- custom fields ----------------------------------------------------

  # The values of the custom fields, keyed by field id.
  def values
    field_values.each_with_object({}) do |field_value, result|
      result[field_value.field_id] = field_value.value
    end
  end

  # The value of a single field.
  def value_for(field)
    return nil if field.blank?

    field_values.detect { |field_value| field_value.field_id == field.id }&.value
  end

  # The fields of the inventory, in the order the owner defined them.
  def fields
    inventory.present? ? inventory.fields : Field.none
  end

  # --- likes ------------------------------------------------------------

  def liked_by?(user)
    return false if user.blank?

    likes.exists?(user_id: user.id)
  end

  # --- search -----------------------------------------------------------

  # Rebuilds the denormalised text that the full text search index is built
  # from.  It contains the custom id and the values of the custom fields.
  #
  # The text is split into words: the full text search of PostgreSQL keeps
  # "OFF-0001" as one word, so "0001" could not be found; after the split
  # the index holds the words "off" and "0001" and both are found.
  def refresh_search_text
    text = normalized_search_text

    update_column(:search_text, text) if search_text != text
  end

  # The text of the item as it is stored for the search.
  def normalized_search_text
    raw = [custom_id, *field_values.map { |field_value| field_value.text_value.to_s }]
          .reject(&:blank?)
          .join(" ")

    raw.scan(/[\p{L}\p{N}]+/u).join(" ")
  end

  private

  # The custom id has to follow the format of the inventory.  The check runs
  # when the id is created and whenever it is changed; ids that were created
  # before the owner changed the format keep working.
  def custom_id_matches_the_inventory_format
    return if inventory.blank?
    return unless new_record? || will_save_change_to_custom_id?

    formatter = inventory.custom_id_formatter
    return if formatter.empty?

    errors.add(:custom_id, formatter.error_message) unless formatter.matches?(custom_id)
  end
end
