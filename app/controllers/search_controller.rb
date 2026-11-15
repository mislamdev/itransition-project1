# The search page.
#
# The same page is used for a text search and for the list of the
# inventories that carry a tag.
class SearchController < ApplicationController
  include Paginates

  def index
    @query = params[:q].to_s.strip
    @tag = find_tag

    search = Search.new(@query, tag: @tag)
    @inventories = inventories(search).includes(:user, :category, :tags)
    @items = search.items.includes(:inventory)
    @tags = search.tags

    respond_to do |format|
      format.html
      format.json do
        render json: {
          query: @query,
          tag: @tag&.name,
          inventories: @inventories.map { |inventory| inventory_json(inventory) },
          items: @items.map { |item| item_json(item) },
          tags: @tags.map { |tag| { id: tag.id, name: tag.name } }
        }
      end
    end
  end

  private

  # The tag that was clicked in the tag cloud.
  def find_tag
    value = params[:tag].presence
    return nil if value.blank?

    tag = Tag.find_by(slug: value.to_s.parameterize)
    tag ||= Tag.find_by(id: value) if value.match?(/\A\d+\z/)
    tag
  end

  # The inventories of the search.
  #
  # A tag without a search text shows the inventories of the tag.
  def inventories(search)
    if @query.blank? && @tag.present?
      return @tag.inventories.latest
    end

    search.inventories
  end

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

  def item_json(item)
    {
      id: item.id,
      custom_id: item.custom_id,
      inventory_id: item.inventory_id,
      inventory_title: item.inventory&.title,
      likes_count: item.likes_count,
      url: item_path(item)
    }
  end
end
