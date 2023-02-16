#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
if ARGV.size < 1
  puts "usage: ./gls2cvs.rb <dirname>"
  exit 1
end
dirname = ARGV[0]
no_entries = 0

Amex = Struct.new(:date,:value_date,:text,:amount,:cr, :lines ,keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.lines = []
  end
end
Line = Struct.new( :line, :x,:y, :part, :slice, :entry, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.part = []
  end
end

class Converter
  @@no_entries = 0
    def initialize(lines:, filename:, write_header: true)
      @current_line = 0
      @lines = parse_lines(lines)
      @log = lines.map(&:clone)
      @entries = []
      @filename = filename
      @data = {}
      @write_header = write_header
      @sizes = Hash.new()
      @slices =  Hash.new{ |hash, key| hash[key] = [] }
      @slice_lines = Hash.new{ |hash, key| hash[key] = [] }

      @@regex = {date: /((\d\d\.\d\d)(\d\d\.\d\d))|(CR)/,
      amount: /([\.\d]+,\d\d)/,
      text: /(^[A-Z][0-9 A-Z\*\.\/-]{2,}|[A-Z][0-9 A-Z\*\.\/-]{2,}$)/
      }
      @@re_cr = /CR/
      @parts = @@regex.keys
      @line_entries = []

    end

    #@@prefix_re = /(\d{4}\.\d):(\d{4}\.\d)-- /
    @@prefix_re = /^(\d{4}\.\d):(\d{4}\.\d)-- (.*)$/
    def parse_lines(lines)
      lines.map do | line |
        m = @@prefix_re.match(line)
        if m
          Line.new(line: m[3], x: m[1], y: m[2])
        else
          STDERR.puts "ERROR: could not parse_line #{line}"
          Line.new(line: line)
        end
      end
    end

    def find_slices
        @parts.each do | part |
          # puts "starting #{part}-----------"
          @lines.each_with_index do |ls, index|
            if (@@regex[part] =~ ls.line)
              @slices[part] << index
              ls.part << part
            end
          end
          # puts "@slices[#{part}]: #{@slices[part].inspect}"
          @slices[part] = @slices[part].slice_when{|prev,cur| cur != prev + 1}.to_a
          @slices[part].reject!{|a| a.size < 4}
          @sizes[part] = @slices[part].map{|sub_a| sub_a.size}
        end
    end
    # this needs to be done first to have a place to store the cr markers
    # that need to be removed from the date slice.
    def fill_amounts
      puts "---- create Entries, fill_amounts----"

      @slices[:amount].each_with_index do |slice, slice_no|
        @line_entries[slice_no] = []
        slice.each_with_index do |index_in_line_array, index_in_slice|
          line = @lines[index_in_line_array]
          amount = line.line.gsub(".","").gsub(",",".").to_f
          entry = Amex.new( amount: amount)
          entry.lines << line
          line.entry = entry
          line.slice = slice_no
          @line_entries[slice_no][index_in_slice] = entry
          #puts @line_entries
        end
      end
    end

    # to find contigious date slices, the CR markers had to be included,
    # as they appear there in the text export.
    # as they belong to the previous line/entry, they need to be removed and
    # the info added to the according entry.
    def remove_cr_lines_from_dates
        @slices[:date].each_with_index do |slice, slice_no|
          amount_index = 0
          cr_indices = []
          slice.each_with_index do |index_in_line_array, index_in_slice|
            puts "processing #{slice_no}/#{index_in_slice} amount_index:#{amount_index}"
            if @lines[index_in_line_array].line =~ @@re_cr
              cr_indices << index_in_slice
              entry = @line_entries[slice_no][amount_index]
              line = @lines[index_in_line_array]
              line.part << :cr
              line.entry = entry
              entry.cr = line.line
              entry.lines << line
              puts "found CR in #{slice_no}/#{index_in_slice}, adding to #{entry}"
            else
              amount_index += 1
            end
          end
          puts "delete:"
          puts slice.inspect
          cr_indices.each { | i | slice.delete_at(i) }
          puts slice.inspect
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
            entry.lines << line
            entry.date = m[2]
            entry.value_date = m[3]
            # puts
            # puts "-------- fill_dates ----------"
            # puts entry.inspect
            # puts line.inspect
            # puts
          else
            STDERR.puts("ERROR: found no date in fille_dates: #{line.line}")
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
      @parts.each do | part |
        @sizes[part] = @slices[part].map{|sub_a| sub_a.size}
      end
    end
    def parse
      puts "----find_slices----"
      find_slices
      fill_amounts
      remove_cr_lines_from_dates
      fill_dates
      fill_texts
    end

    def result
      puts "---- inspect ----"
      puts @lines.join("\n")
      # puts @slices
      check_slice_sizes
      puts @sizes

      @lines.join("\n")
    end
    #attr_reader :log
    def finish_log
      @slices.each do | part, slices |
        slices.each_with_index do | indexes, slice_no |
          indexes.each_with_index do | index, index_in_slice |
          @log[index].prepend("#{part}-#{slice_no+1}-#{index_in_slice+1}--")
        end
      end
    end
    end
    def log
      finish_log
      @log.join
    end

  end


  # ---- main script

  re = /\.txt/
  globpattern = dirname =~ re ? dirname : dirname + "/*.txt"
  files = Dir.glob(globpattern)
  write_header = true
  files.each do | filename |
    begin
      output_filename = filename.gsub(/.txt$/,".csv")
      log_filename = filename.gsub(/.txt$/,".log")

      lines = File.open(filename) { | f |f.readlines }

      converter = Converter.new(lines: lines,filename: filename, write_header: write_header)
      converter.parse

      File.open(log_filename,"w") do | outputfile |
        outputfile.write converter.log
      end
      File.open(output_filename,"w") do | outputfile |
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
