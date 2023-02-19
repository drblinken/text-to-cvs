#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
if ARGV.size < 1
  puts 'usage: ./gls2cvs.rb <dirname>'
  exit 1
end
dirname = ARGV[0]
no_entries = 0
DEL = "\t"

Amex = Struct.new(:id, :date, :value_date, :text, :amount, :cr, :lines, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.lines = []
  end

  def self.cvs_header
    members
  end
  def cvs_values
    [id, date, value_date, "\"#{text}\"", amount.to_s.gsub(".",","), cr, "\"#{lines.map(&:line_no)}\""  ]
  end
end
Line = Struct.new(:line_no, :line, :x, :y, :part, :slice, :entry, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.part = []
  end
  def to_log
    entry_id = entry ? entry.id : "+"
    "#{x}:#{y}-#{part}/#{slice}/#{entry_id}-- #{line}"
  end
end

class Converter
  @@no_entries = 0

  def initialize(lines:, filename:, write_header: true)
    @current_line = 0
    @lines = parse_lines(lines)
    @log = lines.map(&:clone)
    @entries = []
    @filename = filename #  just for context in error/debug output
    @data = {} # ?
    @write_header = write_header # writes header once for all files
    @slices = Hash.new { |hash, key| hash[key] = [] }
    @slice_lines = Hash.new { |hash, key| hash[key] = [] } # ?

    # regexes to identify the main information parts
    @@regex = { date: /((\d\d\.\d\d)(\d\d\.\d\d))|(CR)/,
                amount: /^([\.\d]+,\d\d)/,
                text: /(^[A-Z][0-9 A-Z\*\.\/-]{2,}|[A-Z][0-9 A-Z\*\.\/-]{2,}$)/
    }
    @@re_cr = /CR/
    @@re_saldo = /Saldo.*laufenden.* ([\.\d]+,\d\d)/
    @parts = @@regex.keys
    @line_entries = []

  end

  def inspect
    to_s
  end

  def parse
    find_slices
    fill_amounts
    remove_cr_lines_from_dates
    fill_dates
    fill_texts
    @entries = @line_entries.flatten
    run_checks
  end

  #@@prefix_re = /(\d{4}\.\d):(\d{4}\.\d)-- /
  @@prefix_re = /^(\d{4}\.\d):(\d{4}\.\d)-- (.*)$/

  def parse_lines(lines)
      lines.each_with_index.map do |line, line_no|
      m = @@prefix_re.match(line)
      if m
        Line.new(line_no: line_no, line: m[3], x: m[1], y: m[2])
      else
        STDERR.puts "ERROR: could not parse_line #{line}"
        Line.new(line: line)
      end
    end
  end

  def find_slices
    @parts.each do |part|
      # puts "starting #{part}-----------"
      @lines.each_with_index do |line_struct, index|
        if @@regex[part] =~ line_struct.line
          @slices[part] << index
          line_struct.part << part
        end
      end
      # puts "@slices[#{part}]: #{@slices[part].inspect}"
      # group consecutive lines
      @slices[part] = @slices[part].slice_when { |prev, cur| cur != prev + 1 }.to_a
      # discard
      @slices[part].reject! { |a| a.size < 4 } # this might skip short last page!!!
    end

    # this needs to be done first to have a place to store the cr markers
    # that need to be removed from the date slice.
    def fill_amounts
      # puts '---- create Entries, fill_amounts----'
      entry_no = 0
      @slices[:amount].each_with_index do |slice, slice_no|
        @line_entries[slice_no] = []
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]
          amount_part = @@regex[:amount].match(line.line)[1]
          amount = parse_amount(amount_part)
          entry_no += 1
          entry = Amex.new(id: entry_no, amount: amount)
          entry.lines << line
          line.entry = entry
          line.slice = slice_no
          @line_entries[slice_no][index_in_slice] = entry
          # puts @line_entries
        end
      end
    end
    def parse_amount(amount)
      amount.gsub('.', '').gsub(',', '.').to_f
    end

    # to find contiguous date slices, the CR markers had to be included,
    # as they appear among the date lines in the text export.
    # as they belong to the previous line/entry, they need to be removed and
    # the info added to the according entry.
    def remove_cr_lines_from_dates
      @slices[:date].each_with_index do |slice, slice_no|
        amount_index = 0
        cr_indices = []
        slice.each_with_index do |index_in_line_array, index_in_slice|
          # puts "processing #{slice_no}/#{index_in_slice} amount_index:#{amount_index}"
          if @lines[index_in_line_array].line =~ @@re_cr
            cr_indices << index_in_slice
            entry = @line_entries[slice_no][amount_index-1] # belongs to the entry in the line above
            line = @lines[index_in_line_array]
            line.part << :cr
            line.entry = entry
            line.slice = slice_no
            entry.cr = line.line
            entry.amount = entry.amount * -1
            entry.lines << line
            # puts "found CR in #{slice_no}/#{index_in_slice}, adding to #{entry}"
          else
            amount_index += 1
          end
        end
        # puts 'delete:'
        # puts slice.inspect
        cr_indices.each { |i| slice.delete_at(i) }
        # puts slice.inspect
      end
    end

    def fill_dates
      @slices[:date].each_with_index do |slice, slice_no|
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]
          #    @@regex = {date: /((\d\d\.\d\d)(\d\d\.\d\d))|(CR)/,
          m = @@regex[:date].match(line.line)
          if m
            entry = @line_entries[slice_no][index_in_slice]
            line.entry = entry
            line.slice = slice_no
            entry.lines << line
            entry.date = m[2]
            entry.value_date = m[3]
            # puts
            # puts "-------- fill_dates ----------"
            # puts entry.inspect
            # puts line.inspect
            # puts
          else
            STDERR.puts("ERROR: found no date in fill_dates: #{line.line}")
          end
        end
      end
    end

    def fill_texts
      @slices[:text].each_with_index do |slice, slice_no|
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]
          #  text: /(^[A-Z][0-9 A-Z\*\.\/-]{2,}|[A-Z][0-9 A-Z\*\.\/-]{2,}$)/
          m = @@regex[:text].match(line.line)
          if m
            entry = @line_entries[slice_no][index_in_slice]
            line.entry = entry
            line.slice = slice_no
            entry.lines << line
            entry.text = m[1]
            # puts
            # puts "-------- fill_texts ----------"
            # puts entry.inspect
            # puts line.inspect
            # puts
          else
            STDERR.puts("ERROR: found no text in fill_texts: #{line.line}")
          end
        end
      end
    end

    def check_slice_sizes
      sizes = @parts.to_h { |part| [part, @slices[part].map { |sub_a| sub_a.size }] }
      slice_part_sizes = [] # Hash.new{ |hash, key| hash[key] = {} }
      # {:date=>[14, 21, 36], :amount=>[14, 21, 36], :text=>[14, 21, 36]}
      unless sizes.values.uniq.size == 1
        STDERR.puts "slice lengths are unequal: #{sizes}"
      end
    end
    def find_saldo
      candidates = @lines.map do |l|
        m = @@re_saldo.match(l.line)
        m ? parse_amount(m[1]) : nil
      end.compact
      unless candidates.size == 1
        STDERR.puts "candidates for saldo: #{candidates.inspect}"
      end
      candidates[0]
    end
    def check_balance
      saldo = find_saldo

      bookings = @entries.map{|e| e.amount}
      erstattungen = @entries.select{|e| e.cr == "CR"}.map{|e| e.amount} #.reduce(:+).round(2)
      # puts "erstattungen: #{erstattungen}"
      bookings_sum = bookings.reduce(:+).round(2)
      # delta_balances = (@data["neu"] - @data["alt"]).round(2)
      delta_balances = saldo
      diff = (delta_balances - bookings_sum).round(2)
      unless diff.abs < 0.02
        STDERR.puts "#{@filename} (#{@filetype}) :\nbalances: #{@data}, delta_balances: #{delta_balances}, bookings_sum: #{bookings_sum} (#{bookings.size},#{@entries.size}), diff: #{diff}"
      end
      # puts bookings.inspect
      # puts @entries.first.inspect
    end


    def run_checks
      puts "..."
      check_slice_sizes
      check_balance
    end

    def result
      result = []
      # result << timestamp
      result << Amex.cvs_header.join(DEL) if @write_header
      result << @line_entries.flatten.map{|e| e.cvs_values.join(DEL)}
      result.join("\n") + "\n"
    end

    # attr_reader :log

  end
  def log
    @lines.map(&:to_log).join("\n")
  end
  def timestamp
    require 'date'
    DateTime.now.strftime("Printed on %d.%m.%Y at %H:%M:%S")
  end
end






# ---- main script

re = /\.txt/
globpattern = dirname =~ re ? dirname : dirname + '/*.txt'
files = Dir.glob(globpattern)
write_header = true
files.each do |filename|
  begin
    output_filename = filename.gsub(/.txt$/, '.csv')
    log_filename = filename.gsub(/.txt$/, '.log')

    lines = File.open(filename) { |f| f.readlines }

    converter = Converter.new(lines: lines, filename: filename, write_header: write_header)
    converter.parse
    puts "writing log to #{log_filename}"
    File.open(log_filename, 'w') do |outputfile|
      outputfile.write converter.timestamp
      outputfile.write converter.log
    end
    File.open(output_filename, 'w') do |outputfile|
      outputfile.write converter.result
    end
    write_header = false
  rescue Exception => e
    puts e.message
    puts e.backtrace.inspect
    puts "in #{filename}"
  end
end
#  puts "----------"
#  puts "in #{filename}"
