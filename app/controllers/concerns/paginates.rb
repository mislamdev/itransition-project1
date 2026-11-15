# A very small pagination helper.
#
# The application only needs "next page / previous page", so a gem would be
# more than necessary.  Every list uses the same number of rows per page and
# the same parameters (`page`), which keeps the views simple.
module Paginates
  extend ActiveSupport::Concern

  included do
    helper_method :current_page, :per_page, :total_pages, :total_count
  end

  # The number of rows per page.
  PER_PAGE = 25

  # The number of rows per page, asked for by the visitor.
  def per_page
    requested = params[:per_page].to_i
    requested.positive? ? [requested, 100].min : PER_PAGE
  end

  # The number of the page that was asked for (the first page is 1).
  def current_page
    requested = params[:page].to_i
    requested.positive? ? requested : 1
  end

  # Cuts the given relation into the requested page.
  #
  # Returns the relation; the number of pages is available through
  # `#total_pages` after the relation has been loaded.
  def paginate(scope)
    @total_count = scope.except(:order, :limit, :offset).count
    @total_pages = [(@total_count.to_f / per_page).ceil, 1].max
    @current_page = [current_page, @total_pages].min

    scope.limit(per_page).offset((@current_page - 1) * per_page)
  end

  # The number of pages of the current list.
  def total_pages
    @total_pages || 1
  end

  # The number of rows of the current list.
  def total_count
    @total_count || 0
  end
end
