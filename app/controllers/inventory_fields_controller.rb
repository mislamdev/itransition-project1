# The custom fields of an inventory.
#
# Only the owner of the inventory and the administrators may change the
# fields.  The number of fields of every type is limited (see Field).
class InventoryFieldsController < ApplicationController
  include DeniesAccess

  before_action :require_authentication
  before_action :set_inventory
  before_action :require_inventory_owner
  before_action :set_field, only: [:edit, :update, :destroy]

  # The tab with the fields of the inventory.
  def index
    @fields = @inventory.fields.ordered

    respond_to do |format|
      format.html
      format.json { render json: @fields.map { |field| field_json(field) } }
    end
  end

  # The form of a new field.
  def new
    @field = @inventory.fields.new(field_type: Field::TEXT, show_in_table: true)

    respond_to do |format|
      format.html
      format.json { render json: field_json(@field) }
    end
  end

  # Creates a field.
  def create
    @field = @inventory.fields.new(field_params)

    if @field.save
      respond_to do |format|
        format.html { redirect_to inventory_fields_path(@inventory), notice: t("fields.created") }
        format.json { render json: field_json(@field), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: "invalid", errors: @field.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # The form of a field.
  def edit
    respond_to do |format|
      format.html
      format.json { render json: field_json(@field) }
    end
  end

  # Updates a field.
  def update
    if @field.update(field_params)
      respond_to do |format|
        format.html { redirect_to inventory_fields_path(@inventory), notice: t("fields.updated") }
        format.json { render json: field_json(@field) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { error: "invalid", errors: @field.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # Deletes a field.
  #
  # The values that were filled in for the field are deleted with it.
  def destroy
    @field.destroy!

    respond_to do |format|
      format.html { redirect_to inventory_fields_path(@inventory), notice: t("fields.destroyed") }
      format.json { head :no_content }
    end
  end

  # Sorts the fields (drag and drop).
  #
  # The browser sends the ids of the fields in the new order.  The new
  # positions are written with a single statement, so that the number of
  # queries does not depend on the number of fields.
  def reorder
    ids = Array(params[:ids]).map(&:to_i)
    update_positions(ids)

    respond_to do |format|
      format.html { redirect_to inventory_fields_path(@inventory) }
      format.json { render json: { status: "ok", fields: @inventory.fields.ordered.map { |field| field_json(field) } } }
    end
  end

  private

  # Writes the new position of every field with one statement.
  def update_positions(ids)
    return if ids.empty?

    branches = ids.each_with_index.map { "WHEN ? THEN ?" }.join(" ")
    values = ids.each_with_index.flat_map { |id, index| [id, index] }
    sql = ActiveRecord::Base.sanitize_sql_array(["position = CASE id #{branches} END", *values])
    @inventory.fields.where(id: ids).update_all(sql)
  end

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def set_field
    @field = @inventory.fields.find(params[:id])
  end

  def require_inventory_owner
    return if @inventory.editable_by?(current_user)

    deny_access(t("fields.not_allowed"))
  end

  def field_params
    params.require(:field).permit(:title, :description, :field_type, :show_in_table, :position, options: {})
  end

  def field_json(field)
    {
      id: field.id,
      title: field.title,
      description: field.description,
      field_type: field.field_type,
      show_in_table: field.show_in_table,
      position: field.position,
      choices: field.choices
    }
  end
end
