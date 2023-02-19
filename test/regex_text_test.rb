# frozen_string_literal: true

require 'minitest/autorun'
require './lib/amex/amex_regex.rb'
class RegexTextTest < Minitest::Test
  include AmexRegexp
  def test_address
    line = "American Express Europe S.A. (Germany branch), Theodor-Heuss-Allee 112, 60486 Frankfurt a. M., Registergericht Frankfurt am Main, HRB 112342"
    assert AMREGEX[:text].match(line)
    assert !is_text(line)
  end

  def test_mixed_with_date
    valid = ["3.06 23.06 HOTEL ON BOOKING.COM    AMSTERDAM",
             "4.06 25.06 AMAZON.DE               AMAZON.DE",
             "6.06 29.06 RADISSON BLU WATERFRONT STOCKHOLM",
             "27.06 27.06 A-TRAIN AB              STOCKHOLM",
             "28.06 29.06 AMAZON.DE               AMAZON.DE",
             "29.06 29.06 APPLE.COM/BILL          HOLLYHILL",
             "29.06 30.06 AMAZON.DE               AMAZON.DE",
             "05.07 06.07 PAYPAL *JOHANNESGER     22438890",
             "06.07 07.07 PAYPAL *EASYPARK        0852226737",
             "08.07 08.07 AMZ*AMAZON.DE           AMAZON.DE",
             " 08.07 08.07 AMZN MKTP DE*5L5KR2QX5  800-279-6620",
             " 10.07 10.07 PAYPAL *BERLINERBAE     3022190011",
             " 10.07 10.07 AMZ*AMAZON.DE           800-279-6620",
             " 15.06 15.06 GEBÜHR EXPRESS CASH NUTZUNG"]
    valid.each do | line |
      assert AMREGEX[:text].match(line)
    end

    def test_has_more_capital_letters
      assert has_more_capital_letters("29.06 29.06 APPLE.COM/BILL          HOLLYHILL")
    end

    def test_has_more_capital_letters_false
      line = "American Express Europe S.A. (Germany branch), Theodor-Heuss-Allee 112, 60486 Frankfurt a. M., Registergericht Frankfurt am Main, HRB 112342"
      assert has_more_capital_letters(line)
    end

  end
end
