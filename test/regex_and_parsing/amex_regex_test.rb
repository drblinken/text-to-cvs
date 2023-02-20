require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class TestAmexRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp



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




  def test_payment_received
    assert is_payment("ZAHLUNG ERHALTEN. BESTEN DANK.")
  end


end
