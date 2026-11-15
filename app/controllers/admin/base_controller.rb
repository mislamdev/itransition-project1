# frozen_string_literal: true

module Admin
  # Base class of every controller of the administration area.
  #
  # The only thing it does is to make sure that a signed in administrator
  # is behind the request.
  class BaseController < ApplicationController
    before_action :require_admin
  end
end
