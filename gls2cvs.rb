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
OLD_FIRST_LINE_REGEX = /^(\d\d.\d\d.) +(Wertstellung: (\d\d.\d\d.))?(.*) ([0-9,.]+)([+-])/
# try this with simple variations to make sure all entries are matched
# START_ID_REGEX = /^(\d\d\.\d\d\. \d\d\.\d\d\.)/
START_ID_REGEX = /^(\d\d\.\d\d\. \d\d\.\d\d\.).*(H|S)$/
OLD_START_ID_REGEX = /^(\d\d\.\d\d\.) .*([+-])/
dirname = ARGV[0]
year = ARGV.size >= 2 ? " #{ARGV[1]}" : ""
# puts "hi"
# puts filename


class Converter

  def initialize(lines:, filename:, year: nil)
    @current_line = 0
    @lines = lines # .map(&:strip)
    @entries = []
    @filename = filename
    @year = year
    @data = {}
    @datemap = {"März" => "May","Dez" => "Dec", "Juni" => "June", "Juli" => "July", "Okt" => "Oct"}
    determine_old_or_new
    extract_year
    extract_before_after
  end

  def has_entry()
    # puts "current_line: #{current_line}"
    while (forward && !(@start_id_regex =~ current_line)) do
  #    puts "current_line: #{current_line}"
    end
    return !reached_end
  end

  def read_lines_till_next_header()
    # puts "current_line: #{current_line}"
    result = []
    while (forward && !(@start_id_regex =~ current_line)) do
      result << current_line
    end
    result
  end

  # methods that search in all lines

    def determine_old_or_new
      if @lines.any? { | line | FIRST_LINE_REGEX =~ line }
        @filetype = :new
        @first_line_regex = FIRST_LINE_REGEX
        @start_id_regex = START_ID_REGEX
        return :new
      else
        if @lines.any? { | line | OLD_FIRST_LINE_REGEX =~ line }
          @filetype = :old
          @first_line_regex = OLD_FIRST_LINE_REGEX
          @start_id_regex = OLD_START_ID_REGEX
          return :old
        end
      end
      throw Exception.new("no matching lines found")
    end

    RE_MONTH_YEAR = /\s(\d\d?)\/(\d\d\d\d)[\n\s]*$/
    RE_MY_CAND = /(\d\d?)\/(\d\d\d\d)/

    def extract_year
      # puts @filename
      candidates = @lines.select {|l| l =~ RE_MY_CAND}
      month_year = @lines.map do | line |
        m = RE_MONTH_YEAR.match(line)
        # puts line if m
        m ? [m[1],m[2]] : nil
      end.compact
      one_month_year = month_year.uniq
      if one_month_year.size != 1
        STDERR.puts "#{@filename} (#{@filetype}):\ncould not find unambiguous month/year: #{month_year.inspect}"
        STDERR.puts candidates.inspect
      else
        @month = one_month_year[0][0]
        @year= one_month_year[0][1]
      end
      one_month_year
    end



  RE_ALT_NEU_O = /\s(alt|neu)(.*) ([\d,\.]*)(\+|-)/
  RE_ALT_NEU_N = /(alter|neuer) Kontostand v.*(\n *)? ([\d,\.]*) (H|S)/
  def set_balance(balance)
    if @filetype == :new
      alt_neu = balance[0][0..2]
    else
      alt_neu = balance[0]
    end
    amount = parse_amount(balance[2], balance[3])
    @data[alt_neu] = amount
  end
  def extract_before_after
    alt_neu_re = @filetype == :new ? RE_ALT_NEU_N : RE_ALT_NEU_O
    balances = @lines.join.scan(alt_neu_re).uniq
    # puts balances.inspect
    allowed_matches = 2
    unless balances.size == allowed_matches
      STDERR.puts "#{@filename} (#{@filetype}): couldn't find exactly #{allowed_matches} candidates for alt/neu: #{balances.inspect}"
    else
      balances.each do | m |
          set_balance(m)
      end
    end
    puts "#{@data}"
    puts balances.inspect
    # puts "#{@filename} (#{@filetype}): #{@data}"
  end

  def check_balance
    bookings = @entries.map{|e| parse_amount(e.betrag, e.haben_soll)}
    bookings_sum = bookings.reduce(:+)
    delta_balances = @data["neu"] - @data["alt"]
    diff = delta_balances - bookings_sum
    puts "balances: #{@data}, delta_balances: #{delta_balances}, bookings_sum: #{bookings_sum}, diff: #{diff}"
  end
  def parse_amount(betrag, haben_soll)
    if @filetype == :new
      sign = haben_soll == "S" ? "-" : ""
    else
      sign = haben_soll == "-" ? "-" : ""
    end
    amount_s = "#{sign}#{betrag}"
    amount = amount_s.gsub(".","").gsub(",",".").to_f
    amount
  end

  # was needed for paypal dates
  def translate_month(date)
    result = date
    @datemap.each{|k,v| result = result.gsub(k,v)}
    result
  end

  # https://ruby-doc.org/core-3.1.1/Struct.html
  GLS_Entry = Struct.new(:buchungs_tag, :wert, :vorgang, :betrag, :haben_soll, :who, :verwendungszweck, keyword_init: true)
  def add_year(date)
    "#{date}#{@year}"
  end
  def read_entry()
    header = current_line
    m = @first_line_regex.match(current_line)
    unless m
      STDERR.puts "could not match #{current_line}"
    else
      entry = GLS_Entry.new(buchungs_tag: add_year(m[1]), wert: add_year(m[2]), vorgang: m[3], betrag: m[4], haben_soll: m[5] )
      lines = read_lines_till_next_header()
      entry.who = lines.shift
      entry.verwendungszweck = "\"#{lines.join(" ")}\""

      @entries << entry
    end

#  @result << "#{user}#{DEL}#{datum}#{@year}#{DEL}#{type}#{DEL}#{vorzeichen}#{amount}#{DEL}#{currency}#{DEL}#{notes}"
  end

  # general



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
    result = []
    result << GLS_Entry.new.members.join(DEL)
    result << @entries.map{|e| e.values.map{|v| v.nil? ? "" : v.strip}.join(DEL)}
    result.join("\n")
  end

  def parse
    while (has_entry) do
      read_entry
    end
    check_balance
  end

end

# ---- main script

re = /\.txt/
globpattern = dirname =~ re ? dirname : dirname + "/*.txt"
# puts globpattern
files = Dir.glob(globpattern)
# puts files

files.each do | filename |
  begin
    # puts filename
    output_filename = filename.gsub(/.txt$/,".csv")
    # puts output_filename
    f = File.open(filename)
    lines = f.readlines

    converter = Converter.new(lines: lines,filename: filename)

    converter.parse
    File.open(output_filename,"w") do | outputfile |
      outputfile.write converter.result
    end
  rescue Exception => e
   puts e.message
   puts e.backtrace.inspect
   puts "in #{filename}"
 end
  #  puts "----------"
  #  puts "in #{filename}"
end
