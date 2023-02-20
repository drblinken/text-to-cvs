

require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class CRRegexTest < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp

  def test_1
    assert is_cr("CR")
    end
  def test_2
    assert is_cr(".CR")
  end

end


