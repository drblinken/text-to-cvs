#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
require './lib/amex/amex_regex.rb'
require './lib/amex/line.rb'
require 'logger'
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

class Converter
  include AmexRegexp
  @@no_entries = 0
  attr_reader :logger
  def initialize(lines:, filename:, log_filename:,  logger:, write_header: true)
    @logger = logger
    @current_line = 0
    @lines = parse_lines(lines)
    @log = lines.map(&:clone)
    @entries = []
    @filename = filename #  just for context in error/debug output
    @log_filename = log_filename
    @data = {} # ?
    @write_header = write_header # writes header once for all files
    @slices = Hash.new { |hash, key| hash[key] = [] }
    @slice_lines = Hash.new { |hash, key| hash[key] = [] } # ?

    @@re_cr = /CR/
    @@re_saldo = /Saldo.*laufenden.* ([\.\d]+,\d\d)/
    @parts = Converter::AMREGEX.keys
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

  def parse_lines(lines)
      lines.each_with_index.map do |line, line_no|
        line_struct = parse_prefix(line)
         if line_struct
            line_struct.line_no = line_no
            line_struct
         else
           STDERR.puts "ERROR: in #{@filename} could not parse_line #{line}"
           Line.new(line_no: line_no, line: line)
         end
      end
    end

  def collect_sizes
    @parts.to_h { |part| [part, @slices[part].map { |sub_a| sub_a.size }] }
  end
  def find_slices
    logger.debug("----- find_slices ------")
    @parts.each do |part|
      # puts "starting #{part}-----------"
      @lines.each_with_index do |line_struct, index|
        if re_match(part,line_struct.line)
          @slices[part] << index
          line_struct.part << part
          logger.add(Logger::DEBUG,"#{part} found in line  #{index} --#{line_struct.line}")
        end
      end
      logger.debug("-----part: #{part}------")
      logger.debug("lines found: #{@slices[part]}")
      @slices[part] = @slices[part].slice_when { |prev, cur| cur != prev + 1 }.to_a
      logger.debug("#{@slices[part].size} slices: #{@slices[part]}")
      # discard
      @slices[part].reject! { |a| a.size < 4 } # this might skip short last page!!!
      logger.debug("#{@slices[part].size} slices after discarding short ones: #{@slices[part]}")
    end
    # puts "@slices[#{part}]: #{@slices[part].inspect}"
    # group consecutive lines
    logger.debug("slices after initial collection: #{collect_sizes}")
  end

    def remove_amount_noise!(slice)
      slice.reject! do |line_no|
        is_amount_noise(@lines[line_no].line, logger)
      end
    end

    # this needs to be done first to have a place to store the cr markers
    # that need to be removed from the date slice.
    def fill_amounts
      # puts '---- create Entries, fill_amounts----'
      entry_no = 0
      @slices[:amount].each_with_index do |slice, slice_no|
        remove_amount_noise!(slice)
        logger.debug("slice without noise: #{slice}")
        @line_entries[slice_no] = []
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]

          amount = re_extract_amount(line.line)
          entry_no += 1
          entry = Amex.new(id: entry_no, amount: amount)
          entry.lines << line
          line.entry = entry
          line.slice = slice_no
          line.slice_i = index_in_slice
          @line_entries[slice_no][index_in_slice] = entry
          # puts @line_entries

        end
      end
      logger.debug("-----created line_entries: #{@line_entries}, sizes: #{@line_entries.map(&:size)}")
    end
    def retrieve_entry(slice_no,slice_i)
      entry = @line_entries[slice_no][slice_i]
      unless entry
        write_log
        puts @line_entries
        check_slice_sizes
        logger.error("retrieve_entry: could not find entry #{slice_no}/#{slice_i}")
        logger.error("called from #{caller()[0]}")
        logger.error(collect_sizes)
        # logger.error(@line_entries)
      end
      entry

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
            cr_indices << index_in_line_array
            entry = retrieve_entry(slice_no,amount_index-1)
            line = @lines[index_in_line_array]
            line.part << :cr
            line.entry = entry
            line.slice = slice_no
            line.slice_i = entry.lines[0].slice_i
            entry.cr = line.line
            entry.amount = entry.amount * -1
            entry.lines << line
            # puts "found CR in #{slice_no}/#{index_in_slice}, adding to #{entry}"
          else
            amount_index += 1
          end
        end
        slice.reject!{ |i|  @lines[i].line =~ @@re_cr}
        logger.debug("#{cr_indices.size} cr indices: #{cr_indices}")
      end
    end

    def fill_dates
      @slices[:date].each_with_index do |slice, slice_no|
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]
          m = re_match(:date,line.line)
          if m
            entry = retrieve_entry(slice_no, index_in_slice)
            line.entry = entry
            line.slice = slice_no
            line.slice_i = index_in_slice

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
          m = re_match(:text,line.line)
          if m
            entry = retrieve_entry(slice_no, index_in_slice)
            line.entry = entry
            line.slice = slice_no
            line.slice_i = index_in_slice
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
      sizes = collect_sizes
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


  def write_log
    File.open(@log_filename, 'w') do |outputfile|
      outputfile.write timestamp
      outputfile.write log
    end
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
puts "files: #{files}"
write_header = true
files.each do |filename|
  puts "------ start file #{filename}"
  begin
    output_filename = filename.gsub(/.txt$/, '.csv')
    log_filename = filename.gsub(/.txt$/, '.log')
    logger_filename =  filename.gsub(/.txt$/, '-debug.log')
    lines = File.open(filename) { |f| f.readlines }
    logger = Logger.new(logger_filename, level: "info")
    logger.info("----- start parsing #{filename}")
    converter = Converter.new(lines: lines, filename: filename, log_filename: log_filename, logger: logger, write_header: write_header)
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
