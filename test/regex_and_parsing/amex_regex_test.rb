require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class TestAmexRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp



  def test_dismiss_summary
    line = "1.126,20 -1.154,12 + 864,82 = 836,90"
    assert is_amount_noise(line, nil)
  end






  def test_payment_received
    assert is_payment("ZAHLUNG ERHALTEN. BESTEN DANK.")
  end


end
