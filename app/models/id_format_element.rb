class IdFormatElement < ApplicationRecord
  FIXED = "fixed"
  RANDOM_20 = "random_20"
  RANDOM_32 = "random_32"
  RANDOM_6 = "random_6"
  RANDOM_9 = "random_9"
  GUID = "guid"
  DATETIME = "datetime"
  SEQUENCE = "sequence"

  KINDS = [FIXED, RANDOM_20, RANDOM_32, RANDOM_6, RANDOM_9, GUID, DATETIME, SEQUENCE].freeze

  # The number of bits of every random element.
  RANDOM_BITS = {
    RANDOM_20 => 20,
    RANDOM_32 => 32,
    RANDOM_6 => 6,
    RANDOM_9 => 9
  }.freeze

  # The default date format of a datetime element.
  DEFAULT_DATETIME_FORMAT = "%Y%m%d"

  belongs_to :inventory
  has_many :inventory_sequences, dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :fixed_elements_need_text

  scope :ordered, -> { order(:position, :id) }

  # True for the elements that hand out a number of their own.
  def random?
    RANDOM_BITS.key?(kind)
  end

  # The number of digits the element is padded to, if any.
  def padding
    value = options["padding"]
    value.present? ? value.to_i : nil
  end

  # The strftime format of a datetime element.
  def datetime_format
    options["format"].presence || DEFAULT_DATETIME_FORMAT
  end

  private

  def fixed_elements_need_text
    errors.add(:text, "must not be blank") if kind == FIXED && text.blank?
  end
end
