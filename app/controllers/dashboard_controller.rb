# The main page of the application.
#
# It shows the inventories that were created last, the five most popular
# inventories (the ones with the most items) and a cloud of the tags that are
# in use.
class DashboardController < ApplicationController
  # The number of inventories in the "latest" table.
  LATEST_COUNT = 10
  # The number of inventories in the "most popular" table.
  POPULAR_COUNT = 5
  # The number of tags in the cloud.
  TAG_COUNT = 30

  def index
    @latest_inventories = Inventory.latest.includes(:user, :category, :tags).limit(LATEST_COUNT)
    @popular_inventories = Inventory.popular.includes(:user, :category).limit(POPULAR_COUNT)
    @tags = Tag.with_counts.limit(TAG_COUNT)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          latest_inventories: @latest_inventories.map { |inventory| inventory_json(inventory) },
          popular_inventories: @popular_inventories.map { |inventory| inventory_json(inventory) },
          tags: @tags.map { |tag| { id: tag.id, name: tag.name, count: tag.inventories_count.to_i } }
        }
      end
    end
  end

  private

  def inventory_json(inventory)
    {
      id: inventory.id,
      title: inventory.title,
      description: inventory.description,
      image_url: inventory.image_url,
      is_public: inventory.is_public,
      items_count: inventory.items_count,
      creator: inventory.user&.display_name,
      category: inventory.category&.name,
      url: inventory_path(inventory)
    }
  end
end
