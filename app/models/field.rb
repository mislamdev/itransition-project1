# A custom field of an inventory.
#
# The requirements limit the number of fields of every type (three single
# line texts, three multi line texts, three numbers, three document links
# and three check boxes).  The limit is enforced here so that it holds no
# matter which part of the application creates the field.
class Field < ApplicationRecord
  TEXT = "text"
  TEXTAREA = "textarea"
  NUMBER = "number"
  DOCUMENT = "document"
  BOOLEAN = "boolean"
  SELECT = "select"

  TYPES = [TEXT, TEXTAREA, NUMBER, DOCUMENT, BOOLEAN, SELECT].freeze

  # Maximum number of fields per type.
  LIMITS = {
    TEXT => 3,
    TEXTAREA => 3,
    NUMBER => 3,
    DOCUMENT => 3,
    BOOLEAN => 3,
    SELECT => 3
  }.freeze

  belongs_to :inventory
  has_many :field_values, dependent: :destroy

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 2_000 }
  validates :field_type, inclusion: { in: TYPES }
  validate :type_limit_is_not_exceeded

  scope :ordered, -> { order(:position, :id) }
  scope :in_table, -> { where(show_in_table: true).order(:position, :id) }

  # The options of a select field.
  def choices
    Array(options["values"])
  end

  # True when the field stores a number.
  def numeric?
    field_type == NUMBER
  end

  # True when the field stores a link to a document or an image.
  def document?
    field_type == DOCUMENT
  end

  private

  def type_limit_is_not_exceeded
    limit = LIMITS[field_type]
    return if limit.nil? || inventory.blank?

    taken = inventory.fields.where(field_type: field_type).where.not(id: id).count
    errors.add(:field_type, "allows at most #{limit} #{field_type} fields per inventory") if taken >= limit
  end
end
