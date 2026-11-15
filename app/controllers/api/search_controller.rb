module Api
  # The search of the header.
  class SearchController < BaseController
    def index
      query = params[:q].to_s.strip
      search = Search.new(query)

      render json: {
        query: query,
        inventories: search.inventories.includes(:user, :category).map { |inventory| inventory_json(inventory) },
        items: search.items.includes(:inventory).map { |item| item_json(item) },
        tags: search.tags.map { |tag| { id: tag.id, name: tag.name } }
      }
    end

    private

    def inventory_json(inventory)
      {
        id: inventory.id,
        title: inventory.title,
        description: inventory.description,
        is_public: inventory.is_public,
        items_count: inventory.items_count,
        creator: inventory.user&.display_name,
        category: inventory.category&.name,
        url: inventory_path(inventory)
      }
    end

    def item_json(item)
      {
        id: item.id,
        custom_id: item.custom_id,
        inventory_id: item.inventory_id,
        inventory_title: item.inventory&.title,
        url: item_path(item)
      }
    end
  end
end
