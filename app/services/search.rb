# The full text search of the application.
#
# On PostgreSQL the search uses the generated tsvector columns and their GIN
# indexes, so that the database answers with an index lookup instead of
# scanning the tables.  On SQLite (the portable fallback) the search falls
# back to LIKE queries.
#
# The query is split into words; every word is matched as a prefix, so that
# "XD_63" finds "XD_6332".
class Search
  DEFAULT_LIMIT = 50
  # The number of words that are used at most; a longer query would only
  # slow the search down.
  MAX_TERMS = 8

  attr_reader :query, :inventory, :tag, :category, :limit

  def initialize(query, inventory: nil, tag: nil, category: nil, limit: DEFAULT_LIMIT)
    @query = query.to_s.strip
    @inventory = inventory
    @tag = tag
    @category = category
    @limit = limit
  end

  # True when there is nothing to search for.
  def blank?
    query.blank?
  end

  # The inventories that match the query.
  def inventories
    return Inventory.none if blank?

    scope = Inventory.all
    scope = scope.where(id: tag.inventories.select(:id)) if tag.present?
    scope = scope.where(category_id: category.id) if category.present?
    scope = scope.where(inventory_condition)
    scope.order(created_at: :desc).limit(limit)
  end

  # The items that match the query, optionally limited to one inventory.
  def items
    return Item.none if blank?

    scope = Item.all
    scope = scope.where(inventory_id: inventory.id) if inventory.present?
    scope = scope.where(item_condition)
    scope.order(created_at: :desc).limit(limit)
  end

  # The tags that match the query.
  def tags
    return Tag.none if blank?

    Tag.where("LOWER(tags.name) LIKE ?", "#{sanitized_query.downcase}%").alphabetical.limit(limit)
  end

  # True when the database understands tsvector.
  def self.postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
  end

  private

  def inventory_condition
    if self.class.postgresql? && tsquery.present?
      ["inventories.search_vector @@ to_tsquery('simple', ?)", tsquery]
    else
      ["LOWER(inventories.title) LIKE :q OR LOWER(COALESCE(inventories.description, '')) LIKE :q",
       { q: like_pattern }]
    end
  end

  def item_condition
    if self.class.postgresql? && tsquery.present?
      ["items.search_vector @@ to_tsquery('simple', ?)", tsquery]
    else
      ["LOWER(items.search_text) LIKE :q", { q: like_pattern }]
    end
  end

  # The words of the query, each of them as a prefix.
  #
  # Only letters and digits are used, which makes the query safe to hand
  # over to the database.
  def tsquery
    terms = query.scan(/[\p{L}\p{N}]+/u)
                  .flat_map { |token| token.split(/(?<=\p{L})(?=\p{N})|(?<=\p{N})(?=\p{L})/u) }
                  .first(MAX_TERMS)

    return nil if terms.empty?

    terms.map { |term| "#{term}:*" }.join(" & ")
  end

  def like_pattern
    "%#{sanitized_query.downcase}%"
  end

  # The query without the characters that have a special meaning in a LIKE
  # pattern.
  def sanitized_query
    query.gsub(/[%_\\]/, "")
  end
end
