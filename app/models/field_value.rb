# The value of a custom field for a single item.
#
# Every type gets its own column so that the table stays indexable and no
# casting is needed in SQL.  The generic accessors (#value / #value=) hide
# the difference from the rest of the application.
class FieldValue < ApplicationRecord
  belongs_to :item
  belongs_to :field

  validates :field_id, uniqueness: { scope: :item_id }
  validate :value_matches_the_field_type

  after_save :refresh_item_search_text
  after_destroy :refresh_item_search_text

  # The value of the field, in the type of the field.
  def value
    case field&.field_type
    when Field::NUMBER then number_value
    when Field::BOOLEAN then boolean_value
    else text_value
    end
  end

  # Writes the value into the column that matches the type of the field.
  def value=(raw)
    case field&.field_type
    when Field::NUMBER
      self.number_value = parse_number(raw)
      self.text_value = raw.to_s
      self.boolean_value = nil
    when Field::BOOLEAN
      self.boolean_value = ActiveModel::Type::Boolean.new.cast(raw) || false
      self.text_value = nil
      self.number_value = nil
    else
      self.text_value = raw&.to_s
      self.number_value = nil
      self.boolean_value = nil
    end
  end

  # The value as it is shown in a table cell.
  def display_value
    case field&.field_type
    when Field::BOOLEAN then boolean_value? ? "Yes" : "No"
    when Field::NUMBER then number_value.to_s
    else text_value.to_s
    end
  end

  # The text that ends up in the full text search index.
  def text_value
    super
  end

  private

  # Reads a number.
  #
  # A value that is not a number does not raise here: it is stored as nil
  # and the validation below turns it into a proper error message instead
  # of a 500.
  def parse_number(raw)
    return nil if raw.blank?

    BigDecimal(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def value_matches_the_field_type
    return if field.blank?

    case field.field_type
    when Field::NUMBER
      errors.add(:number_value, "must be a number") if text_value.present? && number_value.nil?
    when Field::BOOLEAN
      errors.add(:boolean_value, "must be true or false") unless boolean_value.in?([true, false])
    when Field::DOCUMENT
      errors.add(:text_value, "must be a valid http(s) link") if text_value.present? && !valid_url?(text_value)
    when Field::SELECT
      if text_value.present? && field.choices.any? && !field.choices.include?(text_value)
        errors.add(:text_value, "must be one of #{field.choices.join(', ')}")
      end
    end
  end

  # True when the given text is a link to a document or an image.
  def valid_url?(value)
    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def refresh_item_search_text
    item&.refresh_search_text
  end
end
