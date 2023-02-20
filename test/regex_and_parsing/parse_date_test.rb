# frozen_string_literal: true

require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class ParseDateTest < Minitest::Test
  include AmexRegexp
  def test_date_regex_eigenvertrieb
    strange = "EIGENVERTRIEB CRSOSFOVE6Y PK 0766996000651"
    assert_nil AMREGEX[:date].match(strange)
  end
  def test_date_regex_cr
    line = "CR"
    assert_equal "CR", date_extract_cr(line)

  end

  def test_date_regex_cr_with_seite
    line = "CRSeite2von4"
    assert_equal "CR", date_extract_cr(line)
  end


end
