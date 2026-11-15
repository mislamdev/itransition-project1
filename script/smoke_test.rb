# A quick end to end check of the domain layer.
#
# Run it with:  bin/rails runner script/smoke_test.rb
#
# It creates a user, an inventory with a custom id format and some fields,
# adds items, searches for them and prints what happened.
user = User.find_or_create_by!(email: "smoke@example.com") do |record|
  record.name = "Smoke Tester"
  record.password = "smoke-test-password"
end

inventory = Inventory.find_or_create_by!(user: user, title: "Smoke inventory") do |record|
  record.description = "Inventory of the **smoke test**"
  record.tag_list = "smoke, test"
end

inventory.id_format_elements.destroy_all
inventory.items.destroy_all
inventory.fields.destroy_all
inventory.id_format_elements.create!(kind: "fixed", text: "INV-", position: 0)
inventory.id_format_elements.create!(kind: "sequence", position: 1, options: { "padding" => 4 })
inventory.id_format_elements.create!(kind: "fixed", text: "-", position: 2)
inventory.id_format_elements.create!(kind: "random_6", position: 3)
inventory.reload

field = inventory.fields.create!(title: "Model", field_type: "text", position: 0, show_in_table: true)
inventory.fields.create!(title: "Price", field_type: "number", position: 1)
inventory.fields.create!(title: "Broken", field_type: "boolean", position: 2)

puts "format:        #{inventory.custom_id_format}"
puts "preview:       #{CustomId::Generator.new(inventory).preview}"

item = inventory.items.new(created_by: user)
item.custom_id = CustomId::Generator.new(inventory).generate
item.field_values.build(field: field, value: "ThinkPad X1")
item.field_values.build(field_id: inventory.fields.find_by(title: "Price").id, value: "1299.99")
item.field_values.build(field_id: inventory.fields.find_by(title: "Broken").id, value: "0")
item.save!

puts "generated id:  #{item.custom_id}"
puts "matches:       #{inventory.custom_id_formatter.matches?(item.custom_id)}"
puts "wrong id:      #{inventory.custom_id_formatter.matches?('nonsense')}"
puts "values:        #{item.values.inspect}"
puts "search text:   #{item.search_text.inspect}"

# A second item must get the next sequence number.
second = inventory.items.new(created_by: user)
second.custom_id = CustomId::Generator.new(inventory).generate
second.save!
puts "second id:     #{second.custom_id}"

# The database refuses a duplicate.
begin
  inventory.items.create!(custom_id: item.custom_id, created_by: user)
  puts "duplicate:     NOT REFUSED (bad)"
rescue ActiveRecord::RecordNotUnique
  puts "duplicate:     refused by the database"
rescue ActiveRecord::RecordInvalid => e
  puts "duplicate:     refused by the validation (#{e.record.errors.full_messages.join(', ')})"
end

# A number that is not a number must not raise.
broken = inventory.items.new(created_by: user)
broken.custom_id = CustomId::Generator.new(inventory).generate
broken.field_values.build(field_id: inventory.fields.find_by(title: "Price").id, value: "not a number")
broken.save
puts "broken number: valid=#{broken.valid?} errors=#{broken.errors.full_messages.inspect}"

# The search finds the item by its custom id and by its values.
search = Search.new("thinkpad", inventory: inventory)
puts "search items:  #{search.items.count} (by value)"
search = Search.new("INV-", inventory: inventory)
puts "search items:  #{search.items.count} (by custom id)"
puts "inventories:   #{Search.new('smoke').inventories.count}"

# The statistics.
statistics = InventoryStatistics.new(inventory)
puts "statistics:    #{statistics.fields.map { |f| [f[:field].title, f[:type], f[:count]] }.inspect}"

puts "OK"
