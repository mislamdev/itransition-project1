module CustomId
  # Builds the custom id of a new item.
  #
  # The generator uses the very same formatter that validates the ids and
  # that shows the preview, so the three of them can never disagree.
  #
  # Numbers of "sequence" elements are reserved in the database, which makes
  # sure that two users adding an item at the same time never receive the
  # same number.  The uniqueness of the id inside the inventory is finally
  # enforced by the database (unique index on inventory_id + custom_id).
  class Generator
    # How many times a colliding id is regenerated before giving up.
    MAX_ATTEMPTS = 20

    attr_reader :inventory

    def initialize(inventory)
      @inventory = inventory
    end

    # Returns a custom id that is not used in this inventory yet.
    def generate
      formatter = inventory.custom_id_formatter
      return fallback_id if formatter.empty?

      MAX_ATTEMPTS.times do
        candidate = formatter.render(sequences: reserved_sequences)
        return candidate unless taken?(candidate)
      end

      raise DuplicateError, I18n.t("custom_id.duplicate", default: "Could not generate a free custom id")
    end

    # The example shown in the preview of the format.
    #
    # The sequence elements show the number that would be used next; every
    # other element shows a random (but valid) value.
    def preview(elements = nil)
      formatter = elements ? Formatter.new(elements) : inventory.custom_id_formatter
      return preview_without_sequences(formatter) if formatter.empty?

      formatter.render(sequences: preview_sequences(formatter))
    end

    private

    def fallback_id
      "ID-#{SecureRandom.hex(4).upcase}"
    end

    # True when the inventory already uses this id.
    def taken?(candidate)
      inventory.items.where(custom_id: candidate).exists?
    end

    # Reserves a number for every sequence element of the format.
    def reserved_sequences
      inventory.id_format_elements.select { |element| element.kind == IdFormatElement::SEQUENCE }
                                  .each_with_object({}) do |element, result|
        result[element.id] = reserve_sequence_value(element)
      end
    end

    # The numbers the preview shows: the number that would be used next.
    def preview_sequences(formatter)
      formatter.elements.select { |element| element.kind == IdFormatElement::SEQUENCE }
                      .each_with_object({}) do |element, result|
        saved = saved_element_for(element)
        result[element.id] = saved ? next_sequence_value(saved) : 1
      end
    end

    def preview_without_sequences(formatter)
      formatter.render(sequences: {})
    end

    # Finds the saved element that belongs to a draft element (the browser
    # sends the elements of the form, the ids are kept for the ones that
    # were saved before).
    def saved_element_for(element)
      return nil if inventory.blank?

      if element.id.present?
        found = inventory.id_format_elements.find_by(id: element.id)
        return found if found
      end

      inventory.id_format_elements.find_by(position: element.position)
    end

    # The number that would be handed out next.
    def next_sequence_value(element)
      counter = InventorySequence.find_by(inventory_id: inventory.id, id_format_element_id: element.id)
      counter&.value.to_i + 1
    end

    # Reserves the next number of a sequence element.
    #
    # The row is locked while it is updated, so that two users never reserve
    # the same number.
    def reserve_sequence_value(element)
      counter = InventorySequence.create_with(value: 0)
                                   .create_or_find_by!(inventory_id: inventory.id,
                                                       id_format_element_id: element.id)

      counter.with_lock do
        counter.update!(value: counter.value + 1)
        counter.value
      end
    end
  end
end
