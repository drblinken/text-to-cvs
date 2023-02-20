
require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class TestAmountRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp

  @@expectations = {
    match_lines: ["5.234,82", "4,99",
                  "Hinweise zu Ihrer Kartenabrechnung8,34",
                  "Sonstige Transaktionen"],

    ignore_lines: []
  }

  def test_dismiss_amount
    line = "Saldodeslaufenden MonatsfürDRBLINKEN XXX 192,83"
    assert is_amount_noise(line, nil)
  end
  def test_is_amount_noise
    assert !is_amount_noise("54,08")
    assert is_amount_noise("Saldodeslaufenden MonatsfürDRBLINKEN")
    assert is_amount_noise("Sonstige Transaktionen")
  end
  def test_match_amount
    m = AMREGEX[:amount]

    @@expectations[:match_lines].each do |line|
      assert(re_match(:amount,line),"should match line: #{line}")
    end
  end

end