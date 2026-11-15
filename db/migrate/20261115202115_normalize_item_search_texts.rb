# Splits the searchable text of the items into words.
#
# PostgreSQL keeps "OFF-0001" as a single word, so a search for "0001" did
# not find the item with the custom id "OFF-0001".  The text is now stored
# as words ("OFF 0001"), which the search of the application builds itself
# (it searches for prefixes of words as well).
class NormalizeItemSearchTexts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE items
      SET search_text = regexp_replace(search_text, '[^[:alnum:]]+', ' ', 'g')
    SQL
  end

  def down
    # The old text cannot be restored; the items are refreshed by the
    # application the next time they are saved.
  end
end
