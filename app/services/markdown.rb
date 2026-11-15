# Renders Markdown.
#
# The descriptions of the inventories and the posts of the discussion are
# written in Markdown.  The rendering itself is done by CommonMarker, this
# module is only the thin wrapper the application uses.
module Markdown
  OPTIONS = {
    parse: { smart: true },
    render: { unsafe: false, hardbreaks: false }
  }.freeze

  # Returns the HTML of the given Markdown text.
  def self.render(text)
    return "" if text.blank?

    Commonmarker.to_html(text.to_s, options: OPTIONS).strip
  end
end
