
require 'minitest/autorun'
require './lib/amex/amex_regex.rb'

class TestAmountRegex < Minitest::Test # MiniTest::Unit::TestCase
  include AmexRegexp

  def self.line4name(line)
    line.gsub(" ","_")
  end

  puts "-------- reloading"
  ["Saldodeslaufenden MonatsfürDRBLINKEN",
   "Sonstige Transaktionen",
   "Saldodeslaufenden MonatsfürDRXXXXXXXXX XXX 192,83",
   "Saldodeslaufenden MonatsfürDRBLINKEN XXX 192,83"
   ].each do |line|
    puts "declaring methods for noise: #{line}"
      define_method("test_match_noise_#{line4name(line)}") do
        # assert is_amount_line(line) != nil
        assert(re_match(:amount,line),"should match line: #{line}")
      end

      define_method("test_identify_noise_#{line4name(line)}") do
        begin
          assert is_amount_noise(line)
        rescue Exception => ex
          assert nil == ex , "message caught in line: #{line}"
        end
      end


    # real amount lines without noise and such
    ["54,08","Saldosonstige Transaktionen 0,19"].each do |line|
      puts "declaring methods for matches: #{line}"

      define_method("test_match_#{line4name(line)}") do
        # assert is_amount_line(line) != nil
        assert(re_match(:amount,line),"should match line: #{line}")
      end
      define_method("test_not_noise#{line4name(line)}") do
        assert !is_amount_noise(line)
      end
    end


    [["5234.82","5.234,82"],
     ["0.19","Saldosonstige Transaktionen 0,19" ],
     ["8.34", "Hinweise zu Ihrer Kartenabrechnung8,34"]].each do | expected_amount, line|
      puts "declaring methods extract amount: #{line}"
      define_method("test_match_2_ea#{line4name(line)}") do
        # assert is_amount_line(line) != nil
        assert(re_match(:amount,line),"should match line: #{line}")
      end
      define_method("test_not_noise_ea_#{line4name(line)}") do
        assert !is_amount_noise(line)
      end
      define_method("test_extract_amount_#{line4name(line)}") do
        actual = re_extract_amount(line).to_s('F')
        assert_equal expected_amount, actual
      end

    end
  end

end


