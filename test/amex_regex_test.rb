require 'minitest/autorun'
# puts $LOAD_PATH
require './lib/amex/amex_regex.rb'

class TestAmountRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp
  @@expectations = {
    match_lines: ["5.234,82", "4,99",
    "Hinweise zu Ihrer Kartenabrechnung8,34","Sonstige Transaktionen"],

    ignore_lines: []
  }

  def test_match_amount
    m = AMREGEX[:amount]

    @@expectations[:match_lines].each do |line|
      assert(re_match(:amount,line),"should match line: #{line}")
    end
  end

  def test_dismiss_amount
    line = "Saldodeslaufenden MonatsfürDRBLINKEN XXX 192,83"
    assert_true is_amount_noise(line, nil)
  end

  def test_dismiss_summary
    line = "1.126,20 -1.154,12 + 864,82 = 836,90"
    assert is_amount_noise(line, nil)
  end

  def test_dismiss_amount
    line = "Saldodeslaufenden MonatsfürDRBLINKEN XXX 192,83"
    is_amount_noise(line)
  end

  def test_extract_amount
    assert_equal 5234.82,re_extract_amount("5.234,82")
    assert_equal 8.34, re_extract_amount("Hinweise zu Ihrer Kartenabrechnung8,34")
  end

  def test_is_amount_noise
    assert !is_amount_noise("54,08")
    assert is_amount_noise("Saldodeslaufenden MonatsfürDRBLINKEN")
    assert is_amount_noise("Sonstige Transaktionen")
  end

  def test_payment_received
    assert is_payment("ZAHLUNG ERHALTEN. BESTEN DANK.")
  end

  def test_date_regex
    strange = "EIGENVERTRIEB CRSOSFOVE6Y PK 0766996000651"
    assert_nil AMREGEX[:date].match(strange)
  end
  def test_date_regex
    m = AMREGEX[:date].match("CR")
    assert_equal "CR", m[0]
  end
end
