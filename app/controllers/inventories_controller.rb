# The inventories: the list, the page of a single inventory and its settings.
class InventoriesController < ApplicationController
  include Paginates

  include DeniesAccess

  before_action :require_authentication, only: [:new, :create, :edit, :update, :destroy, :statistics]
  before_action :set_inventory, only: [:show, :edit, :update, :destroy, :statistics]
  # The settings, the fields, the access list, the custom id format and the
  # statistics belong to the owner of the inventory (and to the admins).
  before_action :require_inventory_owner, only: [:edit, :update, :destroy, :statistics]
  before_action :set_categories, only: [:new, :create, :edit, :update]

  # The list of all inventories.
  def index
    @inventories = paginate(Inventory.latest.includes(:user, :category, :tags))

    respond_to do |format|
      format.html
      format.json { render json: @inventories.map { |inventory| inventory_json(inventory) } }
    end
  end

  # The page of an inventory: the table with its items.
  def show
    @fields = @inventory.fields.in_table
    @items = paginate(@inventory.items.includes(:created_by, field_values: :field).ordered)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          inventory: inventory_json(@inventory),
          fields: @fields.map { |field| field_json(field) },
          items: @items.map { |item| item_json(item) }
        }
      end
    end
  end

  # The form of a new inventory.
  def new
    @inventory = current_user.inventories.new

    respond_to do |format|
      format.html
      format.json { render json: inventory_json(@inventory) }
    end
  end

  # Creates an inventory.
  def create
    @inventory = current_user.inventories.new(inventory_params)

    if @inventory.save
      respond_to do |format|
        format.html { redirect_to @inventory, notice: t("inventories.created") }
        format.json { render json: inventory_json(@inventory), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: "invalid", errors: @inventory.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # The settings of an inventory.
  def edit
    respond_to do |format|
      format.html
      format.json { render json: inventory_json(@inventory) }
    end
  end

  # Updates the settings of an inventory.
  #
  # The inventory uses optimistic locking: the version that the browser sent
  # has to be the current one, otherwise the save is rejected with a
  # conflict (409) and the visitor can decide what to do.
  def update
    if update_inventory
      respond_to do |format|
        format.html { redirect_to @inventory, notice: t("inventories.updated") }
        format.json { render json: inventory_json(@inventory) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: { error: "invalid", errors: @inventory.errors.full_messages,
                         version: @inventory.reload.lock_version },
                 status: :unprocessable_entity
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html { redirect_to edit_inventory_path(@inventory), alert: t("inventories.conflict") }
      format.json { render json: conflict_json, status: :conflict }
    end
  end

  # Deletes an inventory.
  def destroy
    @inventory.destroy!

    respond_to do |format|
      format.html { redirect_to inventories_path, notice: t("inventories.destroyed") }
      format.json { head :no_content }
    end
  end

  # The statistics tab of an inventory.
  def statistics
    @statistics = InventoryStatistics.new(@inventory)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          inventory: inventory_json(@inventory),
          item_count: @statistics.item_count,
          fields: @statistics.fields.map { |statistics| field_statistics_json(statistics) }
        }
      end
    end
  end

  private

  def set_inventory
    @inventory = Inventory.includes(:user, :category, :tags).find(params[:id])
  end

  def set_categories
    @categories = Category.ordered
  end

  # Only the owner of the inventory and the administrators may change it.
  def require_inventory_owner
    return if @inventory.editable_by?(current_user)

    deny_access(t("inventories.not_allowed"))
  end

  # Applies the changes and saves the inventory.
  #
  # Returns false when the inventory is not valid; the version of the
  # inventory is checked by Active Record, a stale write raises
  # ActiveRecord::StaleObjectError.
  def update_inventory
    @inventory.assign_attributes(inventory_params)

    return false unless @inventory.valid?

    @inventory.save!
    true
  end

  def conflict_json
    {
      error: "conflict",
      message: t("inventories.conflict"),
      version: @inventory.reload.lock_version
    }
  end

  def inventory_params
    permitted = params.require(:inventory).permit(:title, :description, :category_id, :image_url,
                                                    :is_public, :lock_version, :tag_list)
    permitted.delete(:lock_version) if permitted[:lock_version].blank?
    permitted
  end

  def inventory_json(inventory)
    {
      id: inventory.id,
      title: inventory.title,
      description: inventory.description,
      image_url: inventory.image_url,
      is_public: inventory.is_public,
      category_id: inventory.category_id,
      category: inventory.category&.name,
      tags: inventory.tags.map(&:name),
      tag_list: inventory.tag_list,
      items_count: inventory.items_count,
      version: inventory.lock_version,
      owner: { id: inventory.user&.id, name: inventory.user&.display_name },
      custom_id_format: inventory.custom_id_format,
      can_edit: inventory.editable_by?(current_user),
      can_write_items: inventory.writable_by?(current_user),
      url: inventory_path(inventory)
    }
  end

  def field_json(field)
    {
      id: field.id,
      title: field.title,
      description: field.description,
      field_type: field.field_type,
      show_in_table: field.show_in_table,
      position: field.position
    }
  end

  def field_statistics_json(statistics)
    {
      field: field_json(statistics[:field]),
      type: statistics[:type],
      count: statistics[:count],
      minimum: statistics[:minimum],
      maximum: statistics[:maximum],
      average: statistics[:average],
      sum: statistics[:sum],
      true_count: statistics[:true_count],
      false_count: statistics[:false_count],
      top_values: statistics[:top_values]
    }
  end
end
