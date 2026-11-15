# Collects the translation keys of the views.
#
#   bin/rails runner script/collect_translations.rb
#
# It prints the keys the views use together with the English text that is
# used as the default, so that the locale files can be built from the text
# that is already written in the interface.
keys = {}

Dir.glob(Rails.root.join("app/views/**/*.erb")).each do |file|
  content = File.read(file)

  # t("key", default: "The English text")
  content.scan(/t\(\s*["']([^"']+)["']\s*,\s*default:\s*["']((?:[^"']|\\['"])*)["']/) do |key, text|
    keys[key] ||= text.gsub("\\'", "'")
  end

  # t("key")
  content.scan(/t\(\s*["']([^"']+)["']\s*\)/) do |key,|
    keys[key] ||= nil
  end
end

puts "# #{keys.size} keys"
keys.sort.each do |key, text|
  puts "#{key}\t#{text.inspect}"
end
