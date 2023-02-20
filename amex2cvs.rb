#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
require './lib/amex/amex_regex.rb'
require './lib/amex/line.rb'
require './lib/amex/amex_entry.rb'
require './lib/helper.rb'
require 'logger'
if ARGV.size < 1
  puts 'usage: ./gls2cvs.rb <dirname>'
  exit 1
end
dirname = ARGV[0]
no_entries = 0
DEL = "\t"

class Converter
  include AmexRegexp
  include Helper
  @@no_entries = 0
  attr_reader :logger

  def initialize(lines:, filename:, log_filename:, logger:, write_header: true)
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
    @@re_other_saldo_text = /Saldo.*sonstige.*Transaktionen/
    @@re_other_saldo = /Saldo.*sonstige.*Transaktionen ([\.\d]+,\d\d)/
    @parts = Converter::AMREGEX.keys
    @line_entries = []

  end

  def inspect
    to_s
  end

  # no longer needed?
  def mark_payments
    @entries.each do |entry|
      if is_payment(entry.text)
        entry.saldo = true
        # entry.text = "#{entry.text} - #{entry.amount}"
        # entry.amount = 0
      end
    end
    puts @entries.size

  end
  def mark_empty_texts
    @entries.each do |entry|
      if entry.text.nil? || entry.text == ""
        text_in_amount = extract_text(entry.lines[0].line)
        entry.text = text_in_amount || "TBD: Text could not be mapped (orphan?)"
      end
    end
  end

  def add_lines_with_hints_to_slices
    [:date, :text].each do | part |
      lines_with_hints = @lines.select{|l| !l.hint.nil? && l.part.include?(part)}
      puts lines_with_hints.inspect
      lines_with_hints.each do | l |
        hint = l.hint
        slice, slice_i = hint.slice, hint.slice_i

        debug = @slices[part][slice]
        target_slice = (@slices[part][slice] ||= [])
        logger.warn("#{part} slice had already an entry: #{hint}") if target_slice[slice_i]
        target_slice[slice_i] = l.line_no

        entry = retrieve_entry(slice,slice_i)
        if part == :date
          add_date_to_entry(l,entry,slice,slice_i)
        else
          text =extract_text(l.line)
          add_text_to_entry(l,entry,slice, slice_i,text)
        end
      end
    end
  end

  def parse
    find_slices
    fill_amounts
    remove_cr_lines_from_dates
    add_lines_with_hints_to_slices
    fill_dates
    fill_texts
    @entries = @line_entries.flatten
    mark_empty_texts
    mark_payments
    write_log
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
        if re_match(part, line_struct.line)
          @slices[part] << index
          line_struct.part << part
          logger.add(Logger::DEBUG, "#{part} found in line  #{index} --#{line_struct.line}")
        end
      end
      @slices[part] = @slices[part].slice_when { |prev, cur| cur != prev + 1 }.to_a
    end
    logger.debug("slice sizes after initial collection: #{collect_sizes}")
    consolidate_slices
  end
  def consolidate_amounts(threshold)
    logger.debug("sizes before consolidate_amounts: #{collect_sizes}")
    @slices[:amount].each do |slice|
      remove_amount_noise!(slice)
    end
    @slices[:amount].reject! { |slice| slice.size == 0 }
    keep_slices = []
    last_index = @slices[:amount].size
    last_index -= 1
    @slices[:amount].each_with_index do | slice, i |
      if (i == last_index) || (slice.size >= threshold)
        keep_slices << i
      end
    end
    logger.debug("keep_slices: #{keep_slices},#{@slices[:amount]}")
    @slices[:amount] = keep_slices.map{|i| @slices[:amount][i]}

    logger.debug("sizes after consolidate_amounts: #{collect_sizes},#{@slices[:amount]} #")
  end
  # group consecutive lines
  def consolidate_slices
    threshold = 4
    #
    consolidate_amounts(threshold)

    # :amount slices duerfen klein sein.
    [:date, :text].each do |part|
      logger.debug("-----part: #{part}------")
      logger.debug("lines found: #{@slices[part]}")
      # @slices[part] = @slices[part].slice_when { |prev, cur| cur != prev + 1 }.to_a
      logger.debug("#{@slices[part].size} slices: #{@slices[part]}")
      # discard short slices if there are not hints in it
      #   this might skip orphans, must be marked by hand in .txt file
      @slices[part].reject! { |a| !keep_slice?(a,threshold) }

      logger.debug("#{@slices[part].size} slices after discarding short ones: #{@slices[part]}")
    end
    logger.debug("slices after consolidation: #{collect_sizes}")

  end

  def keep_slice?(a,threshold)
    return a.size >= threshold

   #  original_size = a.size
   #  filename = @filename
   #  return true if a.size >= threshold
   #  return false if a.none?{ | line_no | !@lines[line_no].hint.nil? }
   #  # ok, it is short but some lines have hints. only keep those!
   #  a.reject!{ | line_no | @lines[line_no].hint.nil? }
   #  return true
  end

  def inject

    @slices[:amount].each_with_index do |slice, slice_index|
      if slice.size < threshold
        logger.warn("this amount slice is small, need to find matching lines!")
        [:dates, :text].each do |part|
          @slices[part].insert(slice_index, [])

        end
      end
    end
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

      logger.debug("slice without noise: #{slice}")
      @line_entries[slice_no] = []
      slice.each_with_index do |index_in_line_array, index_in_slice|
        line = @lines[index_in_line_array]

        amount = re_extract_amount(line.line)
        entry_no += 1
        entry = AmexEntry.new(id: entry_no, amount: amount)
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

  def retrieve_entry(slice_no, slice_i)
    if @line_entries[slice_no].nil? || (entry = @line_entries[slice_no][slice_i]).nil?
      write_log
      logger.error("retrieve_entry: could not find entry #{slice_no}/#{slice_i}")
      logger.error("called from #{caller()[0]}")
      logger.error(collect_sizes)
      logger.error(check_slice_sizes)
      # logger.error("@slices: #{@slices}")
      STDERR.puts("#{@filename} - could not find entry, check debug log file!")
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
        line = @lines[index_in_line_array]
        if line.line =~ @@re_cr
          cr_indices << index_in_line_array
          if hint = line.hint
            entry = @line_entries[hint.slice][hint.slice_i]
          else
            entry = retrieve_entry(slice_no, amount_index - 1)
          end
          line = @lines[index_in_line_array]
          line.part << :cr
          line.entry = entry
          line.slice = slice_no
          line.slice_i = entry.lines[0].slice_i
          entry.cr = date_extract_cr(line.line)
          entry.amount = entry.amount * -1
          entry.lines << line
          # puts "found CR in #{slice_no}/#{index_in_slice}, adding to #{entry}"
        else
          amount_index += 1
        end
      end
      slice.reject! { |i| @lines[i].line =~ @@re_cr }
      logger.debug("#{cr_indices.size} cr indices: #{cr_indices}")
    end
  end

  def fill_dates
    @slices[:date].each_with_index do |slice, slice_no|
      slice.each_with_index do |index_in_line_array, index_in_slice|
        line = @lines[index_in_line_array]
        m = re_match(:date, line.line)
        if m
          entry = retrieve_entry(slice_no, index_in_slice)
          add_date_to_entry(line, entry, slice_no, index_in_slice,  m)
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
        text =extract_text(line.line)
        if text
          entry = retrieve_entry(slice_no, index_in_slice)
          add_text_to_entry( line,entry, slice_no, index_in_slice, text)
        else
          STDERR.puts("ERROR: found no text in fill_texts: #{line.line}")
        end
      end
    end
  end

  def check_slice_sizes
    sizes = collect_sizes
    # {:date=>[14, 21, 36], :amount=>[14, 21, 36], :text=>[14, 21, 36]}
    return true if sizes.values.uniq.size == 1
    msg = "#{@filename}: slice lengths are unequal: #{sizes}"
    puts msg
    logger.error(msg)
    STDERR.puts msg
    return false

  end

  def find_saldo
    candidates = @lines.map do |l|
      m = @@re_saldo.match(l.line)
      m ? parse_amount(m[1]) : nil
    end.compact
    unless candidates.size == 1
      STDERR.puts "candidates for saldo: #{candidates.map{|d| d.to_s('F')}}"
    end
    candidates[0]
  end

  def find_other_saldo

    os_entries = @entries.select{|le| @@re_other_saldo_text.match(le.text)}
    logger.warn("@entries contains more than one line with other saldo size: #{os_entries.size}") if os_entries.size > 1
    return os_entries[0].amount if os_entries.size > 0
    candidates = @lines.map do |l|
      m = @@re_other_saldo.match(l.line)
      m ? parse_amount(m[1]) : nil
    end.compact
    return 0 if candidates.size == 0
    return candidates[0] if candidates.size == 1
    STDERR.puts "more than one candidate for other saldo: #{candidates.inspect}"
    0
  end

  def find_summary
    candidates = @lines.map do |l|
      gutschriften, belastungen = summary(l.line)
      gutschriften ? [parse_amount(gutschriften), parse_amount(belastungen)] : nil
    end.compact
    unless candidates.size == 1
      STDERR.puts "candidates for summary: #{candidates.inspect}"
    end
    candidates[0]
  end

  def check_for_zero(name,expr,binding)
    diff, msg =  eval_and_msg(expr,binding)
    msg = "#{name} in #{@filename}: \n#{msg}"
    if diff.abs < 0.02
      logger.info(msg)
    else
      STDERR.puts msg
      logger.error(msg)
    end
  end
  def check_balance_saldo
    saldo_statement = find_saldo
    other_saldo_statement = find_other_saldo
    saldo_computed = @entries.map { |e| e.saldo ? 0 : e.amount }.reduce(&:+)

    # expr = "saldo_statement = saldo + other_saldo"
    expr = "saldo_diff = saldo_statement + other_saldo_statement - saldo_computed"
    check_for_zero("saldo",expr, binding)
  end

  def check_smoke_test
    entries_to_use = @entries.select{ |e| !@@re_other_saldo_text.match(e.text) }
    puts entries_to_use.inspect
    puts entries_to_use.size
    # this tests various sums
    gutschriften, belastungen = find_summary
    gutschriften_statement = gutschriften.abs
    belastungen_statement = belastungen.abs

    abs_sum_computed = entries_to_use.map { |e| e.amount.abs }.reduce(&:+)
    expr = "abs_diff =  gutschriften + belastungen - abs_sum_computed"
    check_for_zero("smoketest sum absolute values ",expr,binding)

    sum_gutschriften_computed = entries_to_use.map { |e| e.amount < 0 ? e.amount.abs : 0 }.reduce(&:+)
    sum_belastungen_computed = entries_to_use.map { |e| e.amount > 0 ? e.amount.abs : 0 }.reduce(&:+)
    expr = "diff_belastungen = belastungen_statement - sum_belastungen_computed"
    check_for_zero("summe belastungen",expr,binding)
    expr = "diff_gutschriften = gutschriften_statement - sum_gutschriften_computed"
    check_for_zero("summe gutschriften",expr,binding)
  end

  def check_balance
    check_balance_saldo
    check_smoke_test
  end

  def run_checks
    check_slice_sizes
    check_balance
  end

  def result
    result = []
    # result << timestamp
    if @write_header
      header = AmexEntry.cvs_header. << "file name"
      result << header.join(DEL)
    end
    # values = @line_entries.flatten.map { |e| (e.cvs_values.append(@filename)).join(DEL) }
    values = @entries.map { |e| (e.cvs_values.append(@filename)).join(DEL) }
    result.append(*values)
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

  def log_sorted

    relevant = @lines.select { |l| !l.entry.nil? }
    #puts relevant.select { |line| line.y.nil?}.inspect
    # puts relevant.map{  |line| line.y  == "" ? "0000000" : line.y }
    sorted = relevant.sort_by { |line| line.y || "0000000" }
    sorted.map(&:to_log).join("\n")
  end

  def timestamp
    require 'date'
    DateTime.now.strftime("Printed on %d.%m.%Y at %H:%M:%S")
  end

  private

  def add_text_to_entry(line, entry, slice_no, slice_i, text)
    line.entry = entry
    line.slice = slice_no
    line.slice_i = slice_i
    entry.lines << line
    entry.text = text
  end

  def add_date_to_entry(line, entry, slice_no, slice_i, m = nil)
    m = re_match(:date, line.line) unless m
    line.entry = entry
    line.slice = slice_no
    line.slice_i = slice_i
    entry.lines << line
    entry.date = "#{m[2]}.#{YEAR}"
    entry.value_date = "#{m[3]}.#{YEAR}"
  end
end

# ---- main script

re = /\.txt/
globpattern = dirname =~ re ? dirname : dirname + '/*.txt'
files = Dir.glob(globpattern)
puts "files: #{files}"
puts globpattern if files.size == 0
write_header = true

year_match = /.*\/(\d{4}).*/.match(dirname)
YEAR = year_match ? year_match[1] :"2121"
files.each do |filename|
  puts "------ start file #{filename}"
  logger_filename = filename.gsub(/.txt$/, '-debug.log')
  # fatal, error, warn, info, debug
  logger = Logger.new(logger_filename, level: "info")
  logger.info("----- start parsing #{filename}")

  begin
    output_filename = filename.gsub(/.txt$/, '.csv')
    log_filename = filename.gsub(/.txt$/, '.log')
    log_sorted_filename = filename.gsub(/.txt$/, '-sorted.log')

    lines = File.open(filename) { |f| f.readlines }
    converter = Converter.new(lines: lines, filename: filename, log_filename: log_filename, logger: logger, write_header: write_header)
    converter.parse
    puts "writing log to #{log_filename}"

    File.open(log_filename, 'w') do |outputfile|
      outputfile.write converter.timestamp
      outputfile.write converter.log
    end
    # File.open(log_sorted_filename, 'w') do |outputfile|
    #  outputfile.write converter.timestamp
    #  outputfile.write "\n"
    #  outputfile.write converter.log_sorted
    #end
    File.open(output_filename, 'w') do |outputfile|
      outputfile.write converter.result
    end
    write_header = false
  rescue Exception => e
    msg = "error parsing #{filename}\n" + e.message + "\n" + e.backtrace.join("\n")
    logger.error(msg)
    STDERR.puts msg
  end
end
#  puts "----------"
#  puts "in #{filename}"
