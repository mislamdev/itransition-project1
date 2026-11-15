# The "likes" of an item.
#
# A user may like an item once; the database rejects a second like of the
# same user for the same item.
class LikesController < ApplicationController
  before_action :require_authentication
  before_action :set_item

  # Likes an item.
  def create
    like = @item.likes.find_or_initialize_by(user: current_user)
    like.save

    respond_to do |format|
      format.html { redirect_back fallback_location: item_path(@item) }
      format.json { render json: like_json(@item) }
    end
  end

  # Removes the like of an item.
  def destroy
    like = @item.likes.find_by(user: current_user)
    like&.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: item_path(@item) }
      format.json { render json: like_json(@item) }
    end
  end

  private

  def set_item
    @item = Item.find(params[:item_id])
  end

  def like_json(item)
    {
      item_id: item.id,
      likes_count: item.reload.likes_count,
      liked_by_me: item.liked_by?(current_user)
    }
  end
end
