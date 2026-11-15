# The category an inventory belongs to.
#
# The list is predefined (Equipment, Furniture, Book, ...) and maintained in
# the database - the requirements explicitly do not ask for a user interface
# to manage it.
class Category < ApplicationRecord
  has_many :inventories, dependent: :nullify

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  before_validation :derive_slug

  scope :ordered, -> { order(:position, :name) }

  private

  def derive_slug
    self.slug = name.to_s.parameterize if name.present?
  end
end
