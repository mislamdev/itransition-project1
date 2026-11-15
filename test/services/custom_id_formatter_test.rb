# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/authentication_helpers.rb")
require Rails.root.join("test/support/domain_helpers.rb")

# The rules of the custom ids: the same code builds them, validates them and
# shows the preview.
class CustomIdFormatterTest < ActiveSupport::TestCase
  include DomainHelpers

  # Builds a formatter from plain hashes (this is what the preview of the
  # browser sends).
  def formatter(elements)
    CustomId::Formatter.new(elements)
  end

  test "a fixed text is used as it is" do
    subject = formatter([{ kind: "fixed", text: "INV-" }])

    assert_equal "INV-", subject.render
    assert_equal "INV-", subject.format_string
  end

  test "a fixed text may contain any unicode character" do
    subject = formatter([{ kind: "fixed", text: "ქართული-★-" }])

    assert_equal "ქართული-★-", subject.render
    assert subject.matches?("ქართული-★-")
    refute subject.matches?("ქართული-x-")
  end

  test "a six digit element always has six digits" do
    subject = formatter([{ kind: "random_6" }])

    20.times do
      value = subject.render
      assert_match(/\A\d{6}\z/, value)
      assert subject.matches?(value)
    end
  end

  test "a nine digit element always has nine digits" do
    subject = formatter([{ kind: "random_9" }])

    assert_match(/\A\d{9}\z/, subject.render)
  end

  test "a random number of twenty bits fits into seven digits" do
    subject = formatter([{ kind: "random_20" }])

    assert_match(/\A\d{1,7}\z/, subject.render)
  end

  test "a random number of thirty two bits fits into ten digits" do
    subject = formatter([{ kind: "random_32" }])

    assert_match(/\A\d{1,10}\z/, subject.render)
  end

  test "a number may be padded with leading zeroes" do
    subject = formatter([{ kind: "random_6", options: { "padding" => 8 } }])

    assert_match(/\A\d{8}\z/, subject.render)
  end

  test "a guid is a uuid or a compact hexadecimal string" do
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/,
                 formatter([{ kind: "guid" }]).render)
    assert_match(/\A[0-9a-f]{32}\z/,
                 formatter([{ kind: "guid", options: { "format" => "compact" } }]).render)
  end

  test "a date uses the given format" do
    subject = formatter([{ kind: "datetime", options: { "format" => "%Y-%m-%d" } }])

    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, subject.render)
    assert subject.matches?(Time.current.strftime("%Y-%m-%d"))
    refute subject.matches?("not a date")
  end

  test "a sequence is the number that was reserved for it" do
    subject = formatter([{ kind: "sequence", id: 7 }])

    assert_equal "42", subject.render(sequences: { 7 => 42 })
    assert_equal "", subject.render
  end

  test "the format is shown in a readable way" do
    subject = formatter([{ kind: "fixed", text: "INV-" }, { kind: "sequence" }, { kind: "random_6" }])

    assert_equal "INV-{sequence}{random_6}", subject.format_string
  end

  test "the elements are only separated by the text that was written down" do
    subject = formatter([{ kind: "fixed", text: "INV-" }, { kind: "sequence" },
                         { kind: "fixed", text: "-" }, { kind: "random_6" }])

    assert_equal "INV-{sequence}-{random_6}", subject.format_string
    assert_match(/\AINV-\d+-\d{6}\z/, subject.render(sequences: { nil => 7 }))
  end

  test "a value that does not follow the format is refused" do
    subject = formatter([{ kind: "fixed", text: "INV-" }, { kind: "random_6" }])

    assert subject.matches?("INV-123456")
    refute subject.matches?("INV-12345")
    refute subject.matches?("XXX-123456")
    refute subject.matches?("INV-123456X")
    refute subject.matches?(nil)
  end

  test "an empty format accepts everything" do
    subject = formatter([])

    assert subject.empty?
    refute subject.matches?("anything")
  end

  test "the error message names the format" do
    subject = formatter([{ kind: "fixed", text: "INV-" }])

    assert_includes subject.error_message, "INV-"
  end
end
