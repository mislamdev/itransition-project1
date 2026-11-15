# The discussion of an inventory.
#
# The posts are linear: a new post is always appended at the end.  Everybody
# who is looking at the page sees new posts within a few seconds, either
# through the live stream or through the polling of the list.
class CommentsController < ApplicationController
  before_action :require_authentication, only: [:create]
  before_action :set_inventory

  # The posts of the discussion.
  def index
    @comments = comments_scope

    respond_to do |format|
      format.html
      format.json do
        render json: {
          comments: @comments.map { |comment| comment_json(comment) },
          updated_at: @comments.last&.created_at
        }
      end
    end
  end

  # Adds a post to the discussion.
  def create
    @comment = @inventory.comments.new(body: comment_body, user: current_user)

    if @comment.save
      broadcast_comment

      respond_to do |format|
        format.html { redirect_to inventory_comments_path(@inventory), notice: t("comments.created") }
        format.json { render json: comment_json(@comment), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to inventory_comments_path(@inventory), alert: @comment.errors.full_messages.to_sentence }
        format.json { render json: { error: "invalid", errors: @comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  # The posts of the discussion.
  #
  # When the browser asks for the posts that are newer than a given one
  # (`?after=123`), only those posts are returned - that is what the
  # polling of the page uses.
  def comments_scope
    scope = @inventory.comments.includes(:user).chronological
    after = params[:after].presence

    scope = scope.where("comments.id > ?", after.to_i) if after.present?
    scope
  end

  def comment_body
    value = params.dig(:comment, :body) || params[:body]
    value.to_s.strip
  end

  # Sends the new post to everybody who is looking at the discussion.
  def broadcast_comment
    Turbo::StreamsChannel.broadcast_append_to(
      @inventory,
      :comments,
      target: "comments",
      partial: "comments/comment",
      locals: { comment: @comment }
    )
  rescue StandardError => e
    # A broken stream must never stop a post from being stored.
    Rails.logger.warn("Could not broadcast comment: #{e.message}")
  end

  def comment_json(comment)
    {
      id: comment.id,
      body: comment.body,
      rendered_body: comment.rendered_body,
      user: { id: comment.user_id, name: comment.user&.display_name },
      created_at: comment.created_at
    }
  end
end
