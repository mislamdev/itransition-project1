# Builds the locale files of the application.
#
#   bin/rails runner script/build_locales.rb
#
# The texts of the interface come from three places:
#
#   * the views, which use `t("key", default: "The English text")`;
#   * script/translations_es.yml, the Spanish translation of those keys;
#   * the texts of the backend (the messages of the controllers), which are
#     listed in this script.
#
# The script writes config/locales/en.yml and config/locales/es.yml.
require "yaml"

VIEWS = Rails.root.join("app/views")
TRANSLATIONS = Rails.root.join("script/translations_es.yml")

# The texts of the backend: the messages the controllers show.
DOMAIN_TEXTS = {
  "en" => {
    "auth" => {
      "sign_in_required" => "Please sign in to continue.",
      "admin_required" => "You are not allowed to access that page."
    },
    "inventories" => {
      "created" => "The inventory was created.",
      "updated" => "The inventory was updated.",
      "destroyed" => "The inventory was deleted.",
      "conflict" => "This inventory was changed by somebody else. Please reload the page.",
      "not_allowed" => "You are not allowed to change this inventory."
    },
    "items" => {
      "created" => "The item was created.",
      "updated" => "The item was updated.",
      "destroyed" => "The item was deleted.",
      "conflict" => "This item was changed by somebody else. Please reload the page.",
      "not_allowed" => "You are not allowed to change the items of this inventory.",
      "custom_id_taken" => "This custom id is already used in this inventory. Please choose another one."
    },
    "fields" => {
      "created" => "The field was created.",
      "updated" => "The field was updated.",
      "destroyed" => "The field was deleted.",
      "not_allowed" => "You are not allowed to change the fields of this inventory."
    },
    "accesses" => {
      "added" => "The user may now add items to this inventory.",
      "removed" => "The access was removed.",
      "updated" => "The inventory was updated.",
      "user_not_found" => "No user with the name or the email address %{query} was found.",
      "not_allowed" => "You are not allowed to change the access of this inventory."
    },
    "custom_id" => {
      "saved" => "The format of the custom ids was saved.",
      "not_allowed" => "You are not allowed to change the custom ids of this inventory.",
      "error_message" => "does not match the format %{pattern}",
      "duplicate" => "Could not generate a free custom id, please write one yourself."
    },
    "comments" => {
      "created" => "Your post was added."
    },
    "errors" => {
      "invalid" => "The form contains errors.",
      "forbidden" => "You are not allowed to do that.",
      "not_found" => "Nothing was found.",
      "conflict" => "The data was changed by somebody else."
    }
  },
  "es" => {
    "auth" => {
      "sign_in_required" => "Inicia sesión para continuar.",
      "admin_required" => "No tienes permiso para ver esta página."
    },
    "inventories" => {
      "created" => "El inventario se ha creado.",
      "updated" => "El inventario se ha actualizado.",
      "destroyed" => "El inventario se ha eliminado.",
      "conflict" => "Otra persona ha cambiado este inventario. Recarga la página.",
      "not_allowed" => "No tienes permiso para cambiar este inventario."
    },
    "items" => {
      "created" => "El elemento se ha creado.",
      "updated" => "El elemento se ha actualizado.",
      "destroyed" => "El elemento se ha eliminado.",
      "conflict" => "Otra persona ha cambiado este elemento. Recarga la página.",
      "not_allowed" => "No tienes permiso para cambiar los elementos de este inventario.",
      "custom_id_taken" => "Este identificador ya se usa en este inventario. Elige otro."
    },
    "fields" => {
      "created" => "El campo se ha creado.",
      "updated" => "El campo se ha actualizado.",
      "destroyed" => "El campo se ha eliminado.",
      "not_allowed" => "No tienes permiso para cambiar los campos de este inventario."
    },
    "accesses" => {
      "added" => "El usuario ya puede añadir elementos a este inventario.",
      "removed" => "Se ha quitado el acceso.",
      "updated" => "El inventario se ha actualizado.",
      "user_not_found" => "No se ha encontrado ningún usuario con el nombre o el correo %{query}.",
      "not_allowed" => "No tienes permiso para cambiar el acceso de este inventario."
    },
    "custom_id" => {
      "saved" => "Se ha guardado el formato de los identificadores.",
      "not_allowed" => "No tienes permiso para cambiar los identificadores de este inventario.",
      "error_message" => "no coincide con el formato %{pattern}",
      "duplicate" => "No se ha podido generar un identificador libre, escribe uno tú mismo."
    },
    "comments" => {
      "created" => "Tu mensaje se ha añadido."
    },
    "errors" => {
      "invalid" => "El formulario contiene errores.",
      "forbidden" => "No tienes permiso para hacer eso.",
      "not_found" => "No se ha encontrado nada.",
      "conflict" => "Los datos han sido cambiados por otra persona."
    }
  }
}.freeze

# The keys the views use together with their English text.
#
# Keys that are built at runtime (custom_id.help.#{kind}) are skipped: the
# static keys they produce are listed on their own.
def collect_view_texts
  texts = {}

  Dir.glob(VIEWS.join("**/*.erb")).each do |file|
    content = File.read(file)

    content.scan(/t\(\s*["']([^"']+)["']\s*,\s*default:\s*["']((?:[^"']|\\['"])*)["']/) do |key, text|
      next if key.include?('#{')

      texts[key] ||= text.gsub("\\'", "'")
    end

    content.scan(/t\(\s*["']([^"']+)["']\s*\)/) do |key,|
      next if key.include?('#{')

      texts[key] ||= nil
    end
  end

  texts
end

# Turns a flat hash with dotted keys into a nested one.
def nest(flat)
  flat.each_with_object({}) do |(key, value), result|
    parts = key.split(".")
    last = parts.pop
    node = parts.inject(result) do |hash, part|
      hash[part] = {} unless hash[part].is_a?(Hash)
      hash[part]
    end
    node[last] = value
  end
end

# Merges two nested hashes; the values of the first one win.
def merge(base, other)
  base.merge(other) do |_key, old, new|
    old.is_a?(Hash) && new.is_a?(Hash) ? merge(old, new) : old
  end
end

view_texts = collect_view_texts.reject { |key, _text| key == "@" || key == "/" }
spanish = YAML.safe_load_file(TRANSLATIONS) || {}

# A key that the views use without a default has no text of its own; the
# texts of the backend fill those gaps.
english_texts = view_texts.reject { |_key, text| text.nil? }
spanish_texts = view_texts.each_with_object({}) do |(key, text), result|
  value = spanish[key] || text
  result[key] = value unless value.nil?
end

english = { "en" => merge(nest(english_texts), DOMAIN_TEXTS["en"]) }
translated = { "es" => merge(nest(spanish_texts), DOMAIN_TEXTS["es"]) }

Rails.root.join("config/locales/en.yml").write(
  "# The texts of the interface.\n#\n" \
  "# The file is built by script/build_locales.rb; edit the sources (the\n" \
  "# defaults of the views, script/translations_es.yml or the texts of the\n" \
  "# backend in that script) and build it again.\n" \
  "#{english.to_yaml.sub(/\A---\n/, '')}"
)

Rails.root.join("config/locales/es.yml").write(
  "# Los textos de la interfaz en español.\n#\n" \
  "# El archivo se genera con script/build_locales.rb.\n" \
  "#{translated.to_yaml.sub(/\A---\n/, '')}"
)

missing = view_texts.keys.reject { |key| spanish.key?(key) }
puts "views: #{view_texts.size} keys, spanish file: #{spanish.size} keys"
puts "missing translations: #{missing.size}"
puts missing.join(", ") unless missing.empty?
