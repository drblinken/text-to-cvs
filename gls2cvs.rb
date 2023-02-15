#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
# ./gls2cvs.rb test/real_data/test.txt

if ARGV.size < 1
  puts "usage: ./gls2cvs.rb <dirname> [<year>]"
  puts "year will be appended to payment date if given"
  exit 1
end
DEL = "\t"
# DEL = ","
# FIRST_LINE_REGEX = /^(\d\d\.\d\d\. \d\d\.\d\d\.)\s(.*)\s([0-9,.]+) (H|S)$/
FIRST_LINE_REGEX = /^(\d\d\.\d\d\.) (\d\d\.\d\d\.)\s(.*)\s([0-9,.]+) (H|S)$/
# try this with simple variations to make sure all entries are matched
# START_ID_REGEX = /^(\d\d\.\d\d\. \d\d\.\d\d\.)/
START_ID_REGEX = /^(\d\d\.\d\d\. \d\d\.\d\d\.).*(H|S)$/
dirname = ARGV[0]
year = ARGV.size >= 2 ? " #{ARGV[1]}" : ""
# puts "hi"
# puts filename


class Converter

  def initialize(lines,year)
    @current_line = 0
    @lines = lines.map(&:strip)
    @result = []
    @year = year
    @datemap = {"März" => "May","Dez" => "Dec", "Juni" => "June", "Juli" => "July", "Okt" => "Oct"}
  end

  def has_entry()
    # puts "current_line: #{current_line}"
    while (forward && !(START_ID_REGEX =~ current_line)) do
  #    puts "current_line: #{current_line}"
    end
    return !reached_end
  end

  def read_lines_till_next_header()
    # puts "current_line: #{current_line}"
    result = []
    while (forward && !(START_ID_REGEX =~ current_line)) do
      result << current_line
    end
    result
  end

  # was needed for paypal dates
  def translate_month(date)
    result = date
    @datemap.each{|k,v| result = result.gsub(k,v)}
    result
  end

  # https://ruby-doc.org/core-3.1.1/Struct.html
  GLS_Entry = Struct.new(:buchungs_tag, :wert, :vorgang, :betrag, :haben_soll, :who, :verwendungszweck, keyword_init: true)

  def read_entry()
    header = current_line
    m = FIRST_LINE_REGEX.match(current_line)
    unless m
      STDERR.puts "could not match #{current_line}"
    else
      entry = GLS_Entry.new(buchungs_tag: m[1], wert: m[2], vorgang: m[3], betrag: m[4], haben_soll: m[5] )
      lines = read_lines_till_next_header()
      entry.who = lines.shift
      entry.verwendungszweck = "\"#{lines.join(" ")}\""
      @result << entry.values.join(DEL)
    end

#  @result << "#{user}#{DEL}#{datum}#{@year}#{DEL}#{type}#{DEL}#{vorzeichen}#{amount}#{DEL}#{currency}#{DEL}#{notes}"
  end

  def add_header
    entry = GLS_Entry.new
    @result << entry.members.join(DEL)
    #@result << "User#{DEL}Datum#{DEL}Type#{DEL}Amount#{DEL}Currency#{DEL}Notes"
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
    @result.join("\n")
  end

  def parse
    while (has_entry) do
      read_entry
    end
  end

end


files = Dir.glob(dirname+"/*.txt")

files.each do | filename |
  puts filename
  output_filename = filename.gsub(/.txt$/,".csv")
  puts output_filename
  f = File.open(filename)
  lines = f.readlines

  converter = Converter.new(lines,year)
  converter.add_header
  converter.parse
  File.open(output_filename,"w") do | outputfile |
    outputfile.write converter.result
  end
end
