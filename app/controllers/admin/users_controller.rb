# frozen_string_literal: true

module Admin
  # Administration of the user accounts.
  #
  # An administrator can:
  #
  #   * see the list of the accounts;
  #   * block and unblock an account (a blocked account is signed out
  #     immediately);
  #   * delete an account;
  #   * give the administrator role to an account, and take it away.
  #
  # An administrator may also take the administrator role away from
  # *himself*: the change is applied at once and the administrator becomes an
  # ordinary user.
  class UsersController < BaseController
    PER_PAGE = 25

    # Values that are understood as "true" in the parameters.
    TRUTHY = %w[1 true t yes y on admin].freeze

    # GET /admin/users
    def index
      @query = params[:q].to_s.strip
      @page = [params[:page].to_i, 1].max

      scope = filtered_users(@query)
      @total_count = scope.count
      @users = ordered_users(scope).limit(PER_PAGE).offset((@page - 1) * PER_PAGE)

      @user_count = User.count
      @admin_count = User.where(admin: true).count
      @blocked_count = User.where(blocked: true).count
    end

    # PATCH|PUT /admin/users/:id
    def update
      user = User.find(params[:id])
      attributes = requested_changes

      if attributes.empty?
        return redirect_to admin_users_location, notice: I18n.t("admin.users.nothing_to_update", default: "Nothing to update.")
      end

      # Blocking somebody invalidates every session that account has, on
      # every browser.
      if attributes[:blocked] == true && user.respond_to?(:session_version)
        attributes[:session_version] = user.session_version.to_i + 1
      end

      user.update!(attributes)

      if user == current_user
        if attributes[:blocked] == true
          sign_out
          return redirect_to root_path, notice: I18n.t("admin.users.blocked_self", default: "You have blocked your own account and have been signed out.")
        end

        # An administrator is allowed to remove the administrator role from
        # himself. It takes effect immediately: from now on the account is
        # an ordinary one.
        if attributes[:admin] == false
          return redirect_to root_path, notice: I18n.t("admin.users.demoted_self", default: "You have removed your own administrator access.")
        end
      end

      redirect_to admin_users_location, notice: I18n.t("admin.users.updated", default: "The account has been updated.")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_users_location, alert: e.record.errors.full_messages.to_sentence
    end

    # DELETE /admin/users/:id
    def destroy
      user = User.find(params[:id])
      was_current_user = (user == current_user)

      user.destroy!

      if was_current_user
        sign_out
        redirect_to root_path, notice: I18n.t("admin.users.deleted_self", default: "Your account has been deleted.")
      else
        redirect_to admin_users_location, notice: I18n.t("admin.users.deleted", default: "The account has been deleted.")
      end
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => e
      redirect_to admin_users_location, alert: I18n.t("admin.users.delete_failed", default: "The account could not be deleted: #{e.message}")
    end

    private

    # The accounts matching the search field.
    def filtered_users(query)
      return User.all if query.blank?

      pattern = "%#{User.sanitize_sql_like(query.downcase)}%"
      User.where("LOWER(users.name) LIKE :pattern OR LOWER(users.email) LIKE :pattern", pattern: pattern)
    end

    # Accounts sorted by name, then by email.
    def ordered_users(scope)
      scope.order(Arel.sql("LOWER(users.name) ASC, LOWER(users.email) ASC"))
    end

    # The changes asked for by the request.
    #
    # Both `admin=true` and `role=admin` are understood; the same goes for
    # `blocked`.
    def requested_changes
      changes = {}

      if params.key?(:admin)
        changes[:admin] = truthy_param(params[:admin])
      elsif params.key?(:role)
        changes[:admin] = params[:role].to_s.strip.downcase == "admin"
      end

      if params.key?(:blocked)
        changes[:blocked] = truthy_param(params[:blocked])
      end

      changes
    end

    # Reads a parameter as a boolean.
    def truthy_param(value)
      return value if value == true || value == false

      TRUTHY.include?(value.to_s.strip.downcase)
    end
  end
end
