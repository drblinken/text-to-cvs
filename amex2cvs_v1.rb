#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
if ARGV.size < 1
  puts "usage: ./gls2cvs.rb <dirname>"
  exit 1
end
dirname = ARGV[0]

AmexEntry = Struct.new(:date, :value_date, :text, :amount, :cr, keyword_init: true)

class Converter

    def initialize(lines:, filename:, write_header: true)
      @current_line = 0
      @lines = lines
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
    def find_slices
      @annotated_lines = []
        @parts.each do | part |
          # puts "starting #{part}-----------"
          @lines.each_with_index do |line, index|
            if (@@regex[part] =~ line)
              @slices[part] << index
              @log[index].prepend(part.to_s, " - ")
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
      puts "----fill_amounts----"

      @slices[:amount].each_with_index do |slice, slice_no|
        @line_entries[slice_no] = []
        slice.each_with_index do |index_in_line_array, index_in_slice|
          amount = @lines[index_in_line_array].gsub(".","").gsub(",",".").to_f
          @line_entries[slice_no][index_in_slice] = AmexEntry.new(amount: amount)
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
          slice.each_with_index do |index_in_line_array, index_in_slice|
            # puts "processing #{slice_no}/#{index_in_slice} amount_index:#{amount_index}"
            if @lines[index_in_line_array] =~ @@re_cr
              @line_entries[slice_no][amount_index].cr = @lines[index_in_line_array]
              # puts "found CR in #{slice_no}/#{index_in_slice}, adding to #{amount_index}"
            else
              amount_index += 1

            end
          end
          # puts slice.inspect
        end

    end
    def fill_dates
    end
    def fill_texts
    end

    def parse
      puts "----find_slices----"
      find_slices
      fill_amounts
      remove_cr_lines_from_dates
      fill_dates
      fill_texts
      puts "---- inspect ----"
      puts @line_entries.inspect
      puts @slices
      puts @sizes
    end

    def result
      @lines.join("")
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
