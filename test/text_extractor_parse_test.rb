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

  # Match 5
  # 1.	2014.4
  # 2.	2163.2
  # 3.	--1/12/19
  # 4.	1
  # 5.	12
  # 6.	19
  # 7.	CR
  # 8.	CR

  def test_line_with_slice_info
    lines = ["2519.1:2399.5--1/0/7-- CR", "2519.1:2469.2--1/9/16-- CR", "2014.4:2163.2--1/12/19-- CR"]

    hint = Hint.new(slice: 1, slice_i: 0, entry_id: 7)
    expected = Line.new(line: "CR", x: "2519.1", y: "2399.5", hint: hint, part: [])
    assert_equal expected , parse_prefix(lines[0])


  end
end
