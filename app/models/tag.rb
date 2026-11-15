# A tag that inventories can be grouped by.
#
# The list of tags is maintained by the users while they type; unknown tags
# are created on the fly.  The tag cloud and the tag search use this table.
class Tag < ApplicationRecord
  has_many :inventory_tags, dependent: :destroy
  has_many :inventories, through: :inventory_tags

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  before_validation :normalize

  scope :alphabetical, -> { order(:name) }
  # The tags with the number of inventories that use them.
  scope :with_counts, lambda {
    joins(:inventory_tags)
      .group("tags.id")
      .select("tags.*, COUNT(inventory_tags.id) AS inventories_count")
      .order(Arel.sql("COUNT(inventory_tags.id) DESC"), Arel.sql("tags.name ASC"))
  }

  # Finds a tag by its name or creates it.  The lookup ignores the case so
  # that "Laptops" and "laptops" are the same tag.
  def self.find_or_create_by_name(name)
    normalized = name.to_s.strip
    return nil if normalized.blank?

    slug = normalized.parameterize
    existing = where(slug: slug).first
    return existing if existing

    create!(name: normalized)
  rescue ActiveRecord::RecordNotUnique
    where(slug: slug).first
  rescue ActiveRecord::RecordInvalid => error
    # A concurrent request may have created the same tag between the lookup
    # and the insert. The uniqueness validation catches that case before the
    # database constraint does, so look the row up once more.
    existing = where(slug: slug).first
    raise error unless existing

    existing
  end

  # The tags whose name starts with the given text (used by the autocompletion).
  def self.starting_with(text, limit: 10)
    prefix = text.to_s.strip
    return none if prefix.blank?

    where("LOWER(tags.name) LIKE ?", "#{prefix.downcase}%").alphabetical.limit(limit)
  end

  private

  def normalize
    self.name = name.to_s.strip
    self.slug = name.to_s.parameterize if name.present?
  end
end
