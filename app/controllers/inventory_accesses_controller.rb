# The access list of an inventory.
#
# The owner of the inventory decides who may add, change and delete its
# items.  When the inventory is public everybody who is signed in may do so
# and the list is not used at all.
class InventoryAccessesController < ApplicationController
  include DeniesAccess

  before_action :require_authentication
  before_action :set_inventory
  before_action :require_inventory_owner
  before_action :set_access, only: [:destroy]

  # The tab with the list of the users that may write items.
  def index
    @sort = params[:sort].to_s == "email" ? "email" : "name"
    @accesses = sorted_accesses

    respond_to do |format|
      format.html
      format.json { render json: @accesses.map { |access| access_json(access) } }
    end
  end

  # Grants write access to a user.
  #
  # The user is either chosen from the autocompletion (its id is sent as
  # `user_id`) or typed in (the name or the email address is sent as
  # `query`).
  def create(user = find_user)
    if user.nil?
      respond_to do |format|
        format.html do
          redirect_to inventory_accesses_path(@inventory), alert: t("accesses.user_not_found", query: user_query)
        end
        format.json { render json: { error: "not_found", message: t("accesses.user_not_found", query: user_query) }, status: :not_found }
      end
      return
    end

    access = @inventory.inventory_accesses.new(user: user)

    if access.save
      respond_to do |format|
        format.html { redirect_to inventory_accesses_path(@inventory), notice: t("accesses.added") }
        format.json { render json: access_json(access), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to inventory_accesses_path(@inventory), alert: access.errors.full_messages.to_sentence }
        format.json { render json: { error: "invalid", errors: access.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # Removes write access from a user.
  def destroy
    @access.destroy!

    respond_to do |format|
      format.html { redirect_to inventory_accesses_path(@inventory), notice: t("accesses.removed") }
      format.json { head :no_content }
    end
  end

  # Makes the inventory public (or private again).
  #
  # This is the switch of the access tab; it uses the version of the
  # inventory, so that two administrators cannot overwrite each other.
  def update
    @inventory.assign_attributes(is_public: submitted_public_flag, lock_version: submitted_lock_version)

    if @inventory.save
      respond_to do |format|
        format.html { redirect_to inventory_accesses_path(@inventory), notice: t("accesses.updated") }
        format.json { render json: { id: @inventory.id, is_public: @inventory.is_public, version: @inventory.lock_version } }
      end
    else
      respond_to do |format|
        format.html { redirect_to inventory_accesses_path(@inventory), alert: @inventory.errors.full_messages.to_sentence }
        format.json { render json: { error: "invalid", errors: @inventory.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    respond_to do |format|
      format.html { redirect_to inventory_accesses_path(@inventory), alert: t("inventories.conflict") }
      format.json { render json: { error: "conflict", message: t("inventories.conflict"), version: @inventory.reload.lock_version }, status: :conflict }
    end
  end

  # The autocompletion of the users that may be added.
  #
  # The list is searched by name and by email address; the owner of the
  # inventory and the users that already have access are not offered.
  def suggestions
    query = params[:q].to_s.strip
    users = User.active.where("LOWER(users.name) LIKE :q OR LOWER(users.email) LIKE :q", q: "%#{query.downcase}%")
                .order(Arel.sql("LOWER(users.name) ASC"))
                .limit(10)
    users = users.where.not(id: @inventory.user_id)
    users = users.where.not(id: @inventory.inventory_accesses.select(:user_id)) if @inventory.persisted?

    respond_to do |format|
      format.html { redirect_to inventory_accesses_path(@inventory) }
      format.json { render json: users.map { |user| user_json(user) } }
    end
  end

  private

  def set_inventory
    @inventory = Inventory.find(params[:inventory_id])
  end

  def set_access
    @access = @inventory.inventory_accesses.find(params[:id])
  end

  def require_inventory_owner
    return if @inventory.editable_by?(current_user)

    deny_access(t("accesses.not_allowed"))
  end

  # The list of the users that have access, sorted by name or by email.
  def sorted_accesses
    scope = @inventory.inventory_accesses.includes(:user)

    if @sort == "email"
      scope.joins(:user).order(Arel.sql("LOWER(users.email) ASC"), Arel.sql("LOWER(users.name) ASC"))
    else
      scope.sorted
    end
  end

  # The name or the email address that was typed into the form.
  def user_query
    [params[:query], params[:user_query], params.dig(:inventory_access, :query),
     params.dig(:user, :email), params.dig(:user, :name)].find(&:present?).to_s.strip
  end

  # The id of the user that was chosen in the autocompletion.
  def submitted_user_id
    [params[:user_id], params.dig(:inventory_access, :user_id)].find(&:present?)
  end

  # The public flag that was sent.
  def submitted_public_flag
    value = params[:is_public]
    value = params.dig(:inventory_access, :is_public) if value.nil?
    ActiveModel::Type::Boolean.new.cast(value)
  end

  # The version of the inventory that was sent.
  def submitted_lock_version
    value = params[:lock_version]
    value = params.dig(:inventory_access, :lock_version) if value.nil?
    value.present? ? value.to_i : nil
  end

  # Finds the user that shall get access to the inventory.
  #
  # Either the id that was chosen in the autocompletion or the name or the
  # email address that was typed into the field.
  def find_user
    id = submitted_user_id
    return User.find_by(id: id) if id.present?

    query = user_query
    return nil if query.blank?

    User.where("LOWER(users.email) = ?", query.downcase).first ||
      User.where("LOWER(users.name) = ?", query.downcase).first ||
      User.where("LOWER(users.email) LIKE ?", "#{query.downcase}%").first ||
      User.where("LOWER(users.name) LIKE ?", "#{query.downcase}%").first ||
      (User.find_by(id: query) if query.match?(/\A\d+\z/))
  end

  def access_json(access)
    {
      id: access.id,
      user: {
        id: access.user_id,
        name: access.user&.display_name,
        email: access.user&.email,
        avatar_url: access.user&.avatar_url
      }
    }
  end

  # The public data of a user.
  def user_json(user)
    { id: user.id, name: user.display_name, email: user.email, avatar_url: user.avatar_url }
  end
end
