#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
if ARGV.size < 1
  puts "usage: ./paypal2cvs.rb <filename> [<year>]"
  puts "year will be appended to payment date if given"
  exit 1
end
DEL = "\t"
filename = ARGV[0]
year = ARGV.size >= 2 ? " #{ARGV[1]}" : ""
# puts "hi"
# puts filename
f = File.open(filename)
lines = f.readlines

class Converter

  def initialize(lines,year)
    @current_line = 0
    @lines = lines.map(&:strip)
    @result = []
    @year = year
    @datemap = {"März" => "May","Dez" => "Dec", "Juni" => "June", "Juli" => "July", "Okt" => "Oct"}
  end
  def forward_to_user()
    # puts "current_line: #{current_line}"
    while (forward && current_line != "user") do
  #    puts "current_line: #{current_line}"
    end
    return !reached_end
  end

  def translate_month(date)
    result = date
    @datemap.each{|k,v| result = result.gsub(k,v)}
    result
   end

  def read_entry()
    forward
    user = current_line

    forward
    datum_type = current_line
    m = datum_type.match(/(.*)·(.*)/)
    datum = translate_month(m[1])
    type = m[2]

    forward
    amount_currency = current_line
    m = amount_currency.match(/^([-\+]) ([,\d\+]+)(\w+)$/)
    puts "no match! #{amount_currency}" unless m
    plus_minus = m[1]
    amount = m[2]
    currency = m[3]
    zahlungseingang = plus_minus == "+"
    vorzeichen = zahlungseingang ? "- " : ""
    notes = zahlungseingang ? "Zahlungseingang!" : ""
#    @result << "#{user};#{datum_type};#{amount}"
#    @result << "#{user};#{datum}#{@year};#{type};#{vorzeichen}#{amount};#{currency};#{notes}"
    @result << "#{user}#{DEL}#{datum}#{@year}#{DEL}#{type}#{DEL}#{vorzeichen}#{amount}#{DEL}#{currency}#{DEL}#{notes}"
  end

  def add_header
    @result << "User#{DEL}Datum#{DEL}Type#{DEL}Amount#{DEL}Currency#{DEL}Notes"
  end

  def current_line()
    return @lines[@current_line]
  end
  def reached_end()
    @current_line >= @lines.size - 1
  end
  def forward()
    return nil if reached_end
    @current_line = @current_line + 1
  end

  def result
    @result
  end

  def parse
    while (forward_to_user) do
      read_entry
    end
  end

end

converter = Converter.new(lines,year)
converter.add_header
converter.parse

puts converter.result
