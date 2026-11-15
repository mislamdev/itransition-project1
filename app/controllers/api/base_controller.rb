module Api
  # The base class of the JSON endpoints.
  #
  # The endpoints never render a page; they answer with JSON and with the
  # status code that describes the result (200, 201, 401, 403, 404, 409,
  # 422).
  class BaseController < ApplicationController
    # The endpoints never render a page; they answer with JSON and with the
    # status code that describes the result (200, 201, 401, 403, 404, 409,
    # 422).
    #
    # The protection against forged requests stays switched on: the browser
    # sends the token of the page with every request.
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::StaleObjectError, with: :conflict

    private

    def not_found(exception)
      render json: { error: "not_found", message: exception.message }, status: :not_found
    end

    def conflict(_exception)
      render json: { error: "conflict", message: I18n.t("inventories.conflict") }, status: :conflict
    end
  end
end
