# The custom inventory numbers of an inventory.
#
# The owner defines the format of the custom ids: a list of elements (fixed
# text, random numbers, a guid, a date, a sequence) that are put together.
# The tab shows a live preview of the ids the format produces.
class InventoryCustomIdsController < ApplicationController
  include DeniesAccess

  # The preview only computes an example; it changes nothing, so it does not
  # need the token that protects the application against forged requests.
  skip_forgery_protection only: :preview

  before_action :require_authentication
  before_action :set_inventory
  before_action :require_inventory_owner

  # The tab with the elements of the format.
  def edit
    @elements = @inventory.id_format_elements.ordered

    respond_to do |format|
      format.html
      format.json { render json: format_json(@elements) }
    end
  end

  # Saves the format.
  #
  # The browser sends the elements of the form; the ones that were saved
  # before keep their id, the new ones are added and the ones that are not
  # in the form anymore are removed.
  def update
    if save_elements
      respond_to do |format|
        format.html { redirect_to edit_inventory_custom_id_path(@inventory), notice: t("custom_id.saved") }
        format.json { render json: format_json(@inventory.id_format_elements.ordered) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { error: "invalid", errors: @inventory.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # The example of a custom id.
  #
  # The elements may be sent by the browser (a format that is not saved yet)
  # or the saved format is used.
  def preview
    elements = preview_elements
    generator = CustomId::Generator.new(@inventory)
    preview = generator.preview(elements)

    respond_to do |format|
      format.html { redirect_to edit_inventory_custom_id_path(@inventory) }
      format.json do
        render json: {
          preview: preview,
          format: CustomId::Formatter.new(elements).format_string
        }
      end
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def require_inventory_owner
    return if @inventory.editable_by?(current_user)

    deny_access(t("custom_id.not_allowed"))
  end

  # The elements the browser sent, or the saved ones.
  def preview_elements
    elements = params[:elements]
    return @inventory.id_format_elements.ordered.to_a if elements.blank?

    elements = elements.to_unsafe_h.values if elements.respond_to?(:to_unsafe_h)
    Array(elements).map do |element|
      element.respond_to?(:to_unsafe_h) ? element.to_unsafe_h : element
    end
  end

  # Replaces the elements of the format with the ones of the form.
  def save_elements
    submitted = submitted_elements
    kept_ids = submitted.filter_map { |element| element["id"].presence&.to_i }

    @inventory.id_format_elements.ordered.each do |element|
      element.destroy unless kept_ids.include?(element.id)
    end

    submitted.each_with_index do |element, index|
      record = @inventory.id_format_elements.find_by(id: element["id"]) ||
               @inventory.id_format_elements.build
      record.kind = element["kind"]
      record.text = element["text"]
      record.options = element["options"] || {}
      record.position = index
      record.save!
    end

    @inventory.reload
    true
  rescue ActiveRecord::RecordInvalid => e
    @inventory.errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  # The elements of the form.
  def submitted_elements
    elements = params[:elements] || params.dig(:inventory, :elements) || []
    elements = elements.respond_to?(:to_unsafe_h) ? elements.to_unsafe_h.values : Array(elements)

    elements.map do |element|
      element = element.to_unsafe_h if element.respond_to?(:to_unsafe_h)
      element
    end
  end

  def format_json(elements)
    {
      elements: elements.map do |element|
        {
          id: element.id,
          kind: element.kind,
          text: element.text,
          options: element.options || {},
          position: element.position
        }
      end,
      format: CustomId::Formatter.new(elements).format_string
    }
  end
end
