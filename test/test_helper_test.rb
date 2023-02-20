# frozen_string_literal: true

require 'minitest/autorun'
require './lib/helper.rb'
require 'bigdecimal'
require 'bigdecimal/util'

class TestHelperTest < Minitest::Test
  include Helper
  [1695.15, 45.37, 331.24, 91.3, 84.25, 22.09, 53.01, 9.95, 15.9, 24.13, 12.79, 20.5, 2.35, 86.5, 29.67, 39.66, 59.99, 12.64, 2.99, 21.99, 1.45, 75.94, 9.99, 307.87, 36.03, 16.99, 1.16, 55.04, 0.19]

  def test_money_sum
    a = [1695.15, 45.37, 331.24, 91.3, 84.25, 22.09, 53.01, 9.95, 15.9, 24.13, 12.79, 20.5, 2.35, 86.5, 29.67, 39.66, 59.99, 12.64, 2.99, 21.99, 1.45, 75.94, 9.99, 307.87, 36.03, 16.99, 1.16, 55.04, 0.19]
    sum = money_sum(a)
    assert_equal(0,sum)
  end

  def test_money_sum
    a = [1695.15, 45.37, 331.24, 91.3, 84.25, 22.09, 53.01, 9.95, 15.9, 24.13, 12.79, 20.5, 2.35, 86.5, 29.67, 39.66, 59.99, 12.64, 2.99, 21.99, 1.45, 75.94, 9.99, 307.87, 36.03, 16.99, 1.16, 55.04, 0.19]
    sum = money_sum(a)
    sum2 = a.reduce(&:+).round(2)
    a3 = [45.37, 331.24, 91.3, 84.25, 22.09, 53.01, 9.95, 15.9, 24.13, 12.79, 20.5, 2.35, 86.5, 29.67, 39.66, 59.99, 12.64, 2.99, 21.99, 1.45, 75.94, 9.99, 307.87, 36.03, 16.99, 1.16, 55.04, 0.19]
    sum3 = money_sum(a3)
    assert_equal(sum2,sum3)
    assert_equal(sum2,sum)
  end

  def test_money_sum2
    actual = money_sum([1,2,3])
    assert_equal(5,actual)

  end
  def test_money_sum3
    a = [1.20,2.50,34.34]
    sum = 38.04
    a.map{|f| BigDecimal(f.to_s)}
    bd_sum = a.map{|f| BigDecimal(f.to_s)}.reduce(&:+)
    assert_equal(sum, bd_sum)
    actual = money_sum([1.20,2.50,34.34])
    assert_equal(36.85, actual)
    assert_equal(38.040000000000006,[1.20,2.50,34.34].reduce(&:+))
  end
end
