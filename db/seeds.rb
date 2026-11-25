# The data the application starts with.
#
#   bin/rails db:seed
#
# The categories are the ones the requirements mention; new categories are
# added directly in the database.
#
# The demo data makes the application show something right away: a few
# users, a few inventories with fields and items.
#
# The accounts of this file have public passwords, so the file stops itself
# in the production environment. Set ALLOW_SEEDS=true to load it anyway (in
# a staging environment, for example).
if Rails.env.production? && ENV["ALLOW_SEEDS"] != "true"
  puts "The seeds are skipped in the production environment. Set ALLOW_SEEDS=true to load them."
  exit
end

categories = {
  "Equipment" => 1,
  "Furniture" => 2,
  "Book" => 3,
  "Document" => 4,
  "Other" => 5
}

categories.each do |name, position|
  category = Category.find_or_initialize_by(slug: name.parameterize)
  category.name = name
  category.position = position
  category.save!
end

puts "categories: #{Category.count}"

# The administrator of the demo installation.
admin = User.find_or_initialize_by(email: "admin@example.com")
admin.name = "Administrator"
admin.admin = true
admin.password = "administrator"
admin.save!

demo = User.find_or_initialize_by(email: "demo@example.com")
demo.name = "Demo User"
demo.password = "demopassword"
demo.save!

puts "users: #{User.count}"

# Two inventories with fields and items.
office = Inventory.find_or_initialize_by(user: demo, title: "Office equipment")
office.description = "Everything the office owns: laptops, monitors, printers and the like."
office.category = Category.find_by(slug: "equipment")
office.is_public = true
office.tag_list = "hardware, office, equipment"
office.save!

unless office.fields.exists?
  office.fields.create!(title: "Model", description: "The model of the device", field_type: Field::TEXT, position: 0)
  office.fields.create!(title: "Owner", field_type: Field::TEXT, position: 1)
  office.fields.create!(title: "Price", field_type: Field::NUMBER, position: 2)
  office.fields.create!(title: "Broken", field_type: Field::BOOLEAN, position: 3)
end

office.id_format_elements.destroy_all
office.id_format_elements.create!(kind: "fixed", text: "OFF-", position: 0)
office.id_format_elements.create!(kind: "sequence", options: { "padding" => 4 }, position: 1)
office.id_format_elements.create!(kind: "fixed", text: "-", position: 2)
office.id_format_elements.create!(kind: "random_6", position: 3)
office.reload

if office.items.empty?
  [
    ["Personal laptop", "Anna", 1299.99, false],
    ["Fax machine", "Boris", 349.0, true],
    ["Workstation", "Chen", 2499.0, false]
  ].each do |(model, owner, price, broken)|
    item = office.items.new(created_by: demo)
    item.custom_id = CustomId::Generator.new(office).generate
    office.fields.ordered.each do |field|
      value = case field.title
      when "Model" then model
      when "Owner" then owner
      when "Price" then price
      when "Broken" then broken
      end
      item.field_values.build(field: field, value: value)
    end
    item.save!
  end
end

library = Inventory.find_or_initialize_by(user: admin, title: "Library books")
library.description = "The books of the company library. **Markdown** works here, too."
library.category = Category.find_by(slug: "book")
library.tag_list = "books, library"
library.save!

unless library.fields.exists?
  library.fields.create!(title: "Title", field_type: Field::TEXT, position: 0)
  library.fields.create!(title: "Authors", field_type: Field::TEXT, position: 1)
  library.fields.create!(title: "Year", field_type: Field::NUMBER, position: 2)
  library.fields.create!(title: "Annotation", field_type: Field::TEXTAREA, position: 3)
end

library.id_format_elements.destroy_all
library.id_format_elements.create!(kind: "fixed", text: "BK-", position: 0)
library.id_format_elements.create!(kind: "sequence", options: { "padding" => 3 }, position: 1)
library.reload

if library.items.empty?
  [
    ["The Pragmatic Programmer", "Andrew Hunt, David Thomas", 1999, "A book about software that is still worth reading."],
    ["Refactoring", "Martin Fowler", 2018, "How to improve the design of existing code."],
    ["Domain-Driven Design", "Eric Evans", 2003, "The book that introduced the strategic patterns."]
  ].each do |(title, authors, year, annotation)|
    item = library.items.new(created_by: admin)
    item.custom_id = CustomId::Generator.new(library).generate
    library.fields.ordered.each do |field|
      value = case field.title
      when "Title" then title
      when "Authors" then authors
      when "Year" then year
      when "Annotation" then annotation
      end
      item.field_values.build(field: field, value: value)
    end
    item.save!
  end
end

puts "inventories: #{Inventory.count}, items: #{Item.count}, fields: #{Field.count}"
puts "done"
