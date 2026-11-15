# The answer to a request that the visitor is not allowed to make.
#
# A guest is sent to the sign in page (the authentication of the
# application takes care of that); a signed in user that may not do what it
# asked for gets a "403 Forbidden" - the request is refused, nothing is
# changed.
module DeniesAccess
  extend ActiveSupport::Concern

  # Refuses the request.
  #
  #   deny_access(t("items.not_allowed"))
  def deny_access(message = nil)
    message ||= t("errors.forbidden")

    respond_to do |format|
      format.html { render_forbidden(message) }
      format.json { render json: { error: "forbidden", message: message }, status: :forbidden }
      format.any { head :forbidden }
    end
  end

  private

  # Renders the page that says "you may not do that".
  #
  # When the interface provides a page for it (app/views/errors/forbidden),
  # that page is used; otherwise a small page is written here, so that the
  # application never fails because of a missing template.
  def render_forbidden(message)
    if lookup_context.exists?("errors/forbidden")
      render "errors/forbidden", status: :forbidden, locals: { message: message }
    else
      render html: forbidden_page(message), status: :forbidden, layout: false
    end
  end

  # The small fallback page.
  def forbidden_page(message)
    escaped = ERB::Util.html_escape(message)

    <<~HTML
      <!DOCTYPE html>
      <html lang="#{I18n.locale}">
        <head>
          <meta charset="utf-8">
          <title>403 Forbidden</title>
        </head>
        <body>
          <h1>403 — Forbidden</h1>
          <p>#{escaped}</p>
          <p><a href="/">#{ERB::Util.html_escape(t('app.name', default: 'Inventory'))}</a></p>
        </body>
      </html>
    HTML
  end
end
