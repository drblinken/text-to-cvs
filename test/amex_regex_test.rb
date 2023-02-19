require 'minitest/autorun'
# puts $LOAD_PATH
require './lib/amex/amex_regex.rb'

class TestAmountRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp
  @@expectations = {
    match_lines: ["5.234,82", "4,99",
    "Hinweise zu Ihrer Kartenabrechnung8,34"],
    ignore_lines: []
  }

  def test_match
    m = AMREGEX[:amount]

    ["Hinweise zu Ihrer Kartenabrechnung8,34"].each do |line|
      assert(re_match(:amount,line),"should match line: #{line}")
    end
  end

  def test_extract_amount
    assert_equal 5234.82,re_extract_amount("5.234,82")
    assert_equal 8.34, re_extract_amount("Hinweise zu Ihrer Kartenabrechnung8,34")
  end

  def test_is_amount_noise
    assert !is_amount_noise("54,08")
    assert is_amount_noise("Saldodeslaufenden MonatsfürDRBLINKEN")
  end
end
