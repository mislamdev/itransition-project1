# The personal page of a user.
#
# It shows the inventories the user owns and the inventories the user may
# add items to.
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @owned_inventories = @user.inventories.latest.includes(:category, :tags)
    @accessible_inventories = @user.accessible_inventories.latest.includes(:user, :category, :tags)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @user.id,
          name: @user.display_name,
          inventories: @owned_inventories.map { |inventory| inventory_json(inventory) },
          accessible_inventories: @accessible_inventories.map { |inventory| inventory_json(inventory) }
        }
      end
    end
  end

  # The personal page of the signed in user.
  def profile
    return redirect_to sign_in_path unless user_signed_in?

    @user = current_user
    @owned_inventories = @user.inventories.latest.includes(:category, :tags)
    @accessible_inventories = @user.accessible_inventories.latest.includes(:user, :category, :tags)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @user.id,
          name: @user.display_name,
          inventories: @owned_inventories.map { |inventory| inventory_json(inventory) },
          accessible_inventories: @accessible_inventories.map { |inventory| inventory_json(inventory) }
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
