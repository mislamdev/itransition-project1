# The numbers shown on the statistics tab of an inventory.
#
# The aggregations are done by the database: one query per field, never a
# query per item.
class InventoryStatistics
  # The number of most frequent values that are shown for a text field.
  TOP_VALUES = 5

  attr_reader :inventory

  def initialize(inventory)
    @inventory = inventory
  end

  # The number of items of the inventory.
  def item_count
    inventory.items_count
  end

  # The statistics of every field of the inventory.
  def fields
    inventory.fields.map { |field| build_field_statistics(field) }
  end

  private

  def build_field_statistics(field)
    case field.field_type
    when Field::NUMBER then number_statistics(field)
    when Field::BOOLEAN then boolean_statistics(field)
    else text_statistics(field)
    end
  end

  # Count, minimum, maximum, average and sum of a numeric field.
  def number_statistics(field)
    count, minimum, maximum, average, sum = field_values(field)
                                                 .where.not(number_value: nil)
                                                 .pick(Arel.sql("COUNT(*)"), Arel.sql("MIN(number_value)"),
                                                       Arel.sql("MAX(number_value)"), Arel.sql("AVG(number_value)"),
                                                       Arel.sql("SUM(number_value)"))

    {
      field: field,
      type: :number,
      count: count.to_i,
      minimum: minimum,
      maximum: maximum,
      average: average,
      sum: sum
    }
  end

  # The number of items with the flag set and the number without it.
  def boolean_statistics(field)
    values = field_values(field).group(:boolean_value).count

    {
      field: field,
      type: :boolean,
      count: values.values.sum,
      true_count: values.fetch(true, 0),
      false_count: values.fetch(false, 0)
    }
  end

  # The most frequent values of a text field.
  def text_statistics(field)
    values = field_values(field)
              .where.not(text_value: [nil, ""])
              .group(:text_value)
              .order(Arel.sql("COUNT(*) DESC"), Arel.sql("text_value ASC"))
              .limit(TOP_VALUES)
              .count

    {
      field: field,
      type: :text,
      count: values.values.sum,
      top_values: values.map { |value, count| { value: value, count: count } }
    }
  end

  # The values of one field of this inventory.
  #
  # The relation is built directly (and not through the fields of the
  # inventory) so that the aggregation is not disturbed by the order of the
  # fields.
  def field_values(field)
    FieldValue.joins(:item).where(items: { inventory_id: inventory.id }, field_id: field.id)
  end
end
