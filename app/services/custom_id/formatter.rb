module CustomId
  # Knows how to build the custom id of an inventory and how to validate one.
  #
  # The formatter is the single place where the rules of a format live, so
  # the id that is stored, the id that is validated when it is edited and
  # the example that is shown in the preview can never disagree.
  #
  # A format is a list of elements:
  #
  #   fixed       a piece of literal text (any Unicode character)
  #   random_20   a random number of 20 bits
  #   random_32   a random number of 32 bits
  #   random_6    a random number of 6 digits
  #   random_9    a random number of 9 digits
  #   guid        a globally unique identifier
  #   datetime    the date and time of the creation of the item
  #   sequence    the next number of a counter
  #
  # Every element may carry options, e.g. `{"padding": 6}` for a number that
  # is padded with leading zeroes.
  class Formatter
    # The maximum value of every random element.
    RANDOM_MAXIMUM = {
      IdFormatElement::RANDOM_20 => 1_048_575,
      IdFormatElement::RANDOM_32 => 4_294_967_295,
      IdFormatElement::RANDOM_6 => 999_999,
      IdFormatElement::RANDOM_9 => 999_999_999
    }.freeze

    # The maximum number of digits of every random element.
    RANDOM_DIGITS = {
      IdFormatElement::RANDOM_20 => 7,
      IdFormatElement::RANDOM_32 => 10,
      IdFormatElement::RANDOM_6 => 6,
      IdFormatElement::RANDOM_9 => 9
    }.freeze

    # The number of digits the "digit" elements use by default.  A 6 digit
    # element always has six digits (with leading zeroes), a 9 digit element
    # always has nine.  The elements that are defined by a number of bits
    # keep their natural length.
    DEFAULT_PADDING = {
      IdFormatElement::RANDOM_6 => 6,
      IdFormatElement::RANDOM_9 => 9
    }.freeze

    # One element of a format.  It is built from an IdFormatElement record
    # or from a plain hash (the preview receives hashes from the browser).
    Element = Struct.new(:kind, :text, :options, :id, :position, keyword_init: true) do
      # The number of digits the element is padded to.
      #
      # An explicit padding wins; the digit elements (6 and 9 digits) have a
      # padding of their own, the elements that are defined by a number of
      # bits keep their natural length.
      def padding
        value = options["padding"]
        return value.to_i if value.present?

        Formatter::DEFAULT_PADDING[kind]
      end

      def datetime_format
        options["format"].presence || IdFormatElement::DEFAULT_DATETIME_FORMAT
      end

      def guid_format
        options["format"].presence || "hyphenated"
      end
    end

    attr_reader :elements

    def initialize(elements = [])
      @elements = Array(elements).map { |element| self.class.normalize(element) }.compact
    end

    # True when the format does not contain a single element.
    def empty?
      elements.empty?
    end

    # A readable description of the format, e.g. "INV-{sequence}-{random_6}".
    def format_string
      elements.map { |element| placeholder(element) }.join
    end

    # Builds a value.
    #
    # The context may carry the numbers that were reserved for the sequence
    # elements (`{ sequences: { element_id => 3 } }`); without them a
    # sequence element renders as an empty string, which is what the preview
    # of a format without a saved format uses.
    def render(context = {})
      sequences = context[:sequences] || {}
      elements.map { |element| value_for(element, sequences) }.join
    end

    # True when the given value follows the format.
    def matches?(value)
      return false if value.blank?

      regexp.match?(value.to_s)
    end

    # The message shown when a value does not follow the format.
    def error_message
      I18n.t("custom_id.error_message", pattern: format_string, default: "does not match the format %{pattern}")
    end

    # The regular expression a valid custom id has to match.
    def regexp
      @regexp ||= /\A#{elements.map { |element| fragment_for(element) }.join}\z/
    end

    # The example shown in the preview of the format.
    def preview(sequences = {})
      render(sequences: sequences)
    end

    class << self
      # Builds an element from a record, from a hash or from the parameters
      # the browser sent.
      def normalize(element)
        case element
        when IdFormatElement
          Element.new(kind: element.kind, text: element.text, options: element.options || {},
                      id: element.id, position: element.position)
        when Hash
          build_element(element)
        else
          # ActionController::Parameters and everything else that behaves
          # like a hash.
          return nil unless element.respond_to?(:to_unsafe_h)

          build_element(element.to_unsafe_h)
        end
      end

      private

      def build_element(attributes)
        options = attributes["options"] || attributes[:options] || {}

        Element.new(kind: attributes["kind"] || attributes[:kind],
                    text: attributes["text"] || attributes[:text],
                    options: options,
                    id: attributes["id"] || attributes[:id],
                    position: attributes["position"] || attributes[:position] || 0)
      end
    end

    private

    # The value of a single element.
    def value_for(element, sequences)
      case element.kind
      when IdFormatElement::FIXED
        element.text.to_s
      when IdFormatElement::GUID
        guid_value(element)
      when IdFormatElement::DATETIME
        Time.current.strftime(element.datetime_format)
      when IdFormatElement::SEQUENCE
        number = sequences[element.id]
        number.nil? ? "" : pad(number.to_i, element.padding)
      else
        maximum = RANDOM_MAXIMUM[element.kind]
        number = maximum.nil? ? SecureRandom.random_number(1_000_000) : SecureRandom.random_number(maximum + 1)
        pad(number, element.padding)
      end
    end

    def guid_value(element)
      case element.guid_format
      when "compact" then SecureRandom.hex(16)
      when "uppercase" then SecureRandom.uuid.upcase
      else SecureRandom.uuid
      end
    end

    # Adds leading zeroes.
    def pad(number, padding)
      return number.to_s if padding.nil? || padding <= 0

      number.to_s.rjust(padding, "0")
    end

    # The readable placeholder of an element.
    def placeholder(element)
      case element.kind
      when IdFormatElement::FIXED then element.text.to_s
      else "{#{element.kind}}"
      end
    end

    # The regular expression fragment of an element.
    def fragment_for(element)
      case element.kind
      when IdFormatElement::FIXED
        Regexp.escape(element.text.to_s)
      when IdFormatElement::GUID
        element.guid_format == "compact" ? "[0-9a-f]{32}" : "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
      when IdFormatElement::DATETIME
        datetime_fragment(element.datetime_format)
      when IdFormatElement::SEQUENCE
        element.padding ? "\\d{#{element.padding}}" : "\\d{1,}"
      else
        # The digit elements always have exactly as many digits as their
        # name says, the bit elements keep their natural length.
        element.padding ? "\\d{#{element.padding}}" : "\\d{1,#{RANDOM_DIGITS.fetch(element.kind, 10)}}"
      end
    end

    # Turns a strftime format into a regular expression, so that a date can
    # be validated as well.
    def datetime_fragment(format)
      fragment = +""

      format.to_s.scan(/%[a-zA-Z%]|./m).each do |token|
        case token
        when "%Y" then fragment << '\d{4}'
        when "%y" then fragment << '\d{2}'
        when "%m", "%d", "%H", "%M", "%S" then fragment << '\d{2}'
        when "%j" then fragment << '\d{1,3}'
        when "%L" then fragment << '\d{3}'
        when "%N" then fragment << '\d{1,9}'
        when "%b", "%B", "%a", "%A" then fragment << '[\w]+'
        when "%p" then fragment << "[AaPp][Mm]"
        when "%%" then fragment << "%"
        else fragment << Regexp.escape(token)
        end
      end

      fragment
    end
  end
end
