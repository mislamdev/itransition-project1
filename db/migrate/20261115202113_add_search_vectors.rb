# Full text search support.
#
# PostgreSQL gets a stored `tsvector` column plus a GIN index for every
# searchable table, which keeps the search an index lookup instead of a table
# scan. The vector is a *generated* column, so it can never drift away from
# the data it describes.
#
# On SQLite (the portable fallback) the vectors are skipped and the search
# service falls back to indexed LIKE queries.
class AddSearchVectors < ActiveRecord::Migration[8.1]
  def up
    return unless postgresql?

    add_column :inventories, :search_vector, :tsvector, null: true, stored: true,
                        as: "to_tsvector('simple'::regconfig, coalesce(title, '') || ' ' || coalesce(description, ''))"
    add_index :inventories, :search_vector, using: :gin

    add_column :items, :search_vector, :tsvector, null: true, stored: true,
                     as: "to_tsvector('simple'::regconfig, coalesce(search_text, ''))"
    add_index :items, :search_vector, using: :gin
  end

  def down
    return unless postgresql?

    remove_index :items, :search_vector
    remove_column :items, :search_vector
    remove_index :inventories, :search_vector
    remove_column :inventories, :search_vector
  end

  private

  def postgresql?
    connection.adapter_name.downcase.include?("postgres")
  end
end
