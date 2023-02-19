# frozen_string_literal: true

require 'minitest/autorun'
require './lib/amex/amex_regex.rb'
class TextExtractorParseTest < Minitest::Test
  include AmexRegexp
  def test_empty_line
    line = "3041.9:3078.5--"
    expected = Line.new(line: "", x: "3041.9", y: "3078.5", part: [])
    assert_equal expected,parse_prefix(line)
  end

  def test_line
    line = "4041.9:4078.5-- Monatsabrechnung"
    expected = Line.new(line: "Monatsabrechnung", x: "4041.9", y: "4078.5", part: [])
    assert_equal expected ,parse_prefix(line)
  end
end
