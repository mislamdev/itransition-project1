# A post in the discussion of an inventory.
#
# The discussion is linear: a post is always appended at the end and is never
# inserted between two other posts.
class Comment < ApplicationRecord
  belongs_to :inventory
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5_000 }

  scope :chronological, -> { order(:created_at, :id) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # The body rendered as Markdown.
  def rendered_body
    Markdown.render(body)
  end
end
