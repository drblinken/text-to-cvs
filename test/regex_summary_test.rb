# frozen_string_literal: true

require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class RegexSummaryTest < Minitest::Test
  include AmexRegexp
  # ([\.\d]+,\d\d) ?\- ?([\.\d]+,\d\d) ?\+ ?([\.\d]+,\d\d) ?= ?([\.\d]+,\d\d)
  def test_summary
    lines = ["4.195,15 -2.500,00 + 35,37=1.730,52","2.113,34 - 2.151,39 + 642,68 = 604,63Seite  1 von 4",
     "4.195,15-2.500,00+35,37=1.730,52",
             "1.460,68 - 64,62 + 1.115,73 = 2.511,79Seite  1 von 4"]
    lines.each do | line |
      assert !summary(line).nil?
    end
  end
end

