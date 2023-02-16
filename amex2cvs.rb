#!/Users/kleinen/.rvm/rubies/ruby-3.1.3/bin/ruby
if ARGV.size < 1
  puts "usage: ./gls2cvs.rb <dirname>"
  exit 1
end
dirname = ARGV[0]



class Converter

    def initialize(lines:, filename:, write_header: true)
      @current_line = 0
      @lines = lines
      @entries = []
      @filename = filename
      @data = {}
      @write_header = write_header
      @sizes = Hash.new()
      @slices =  Hash.new{ |hash, key| hash[key] = [] }
      @slice_lines = Hash.new{ |hash, key| hash[key] = [] }
      @regex = {date: /((\d\d\.\d\d)(\d\d\.\d\d))|(CR)/,
      amount: /([\.\d]+,\d\d)/,
      text: /(^[A-Z][0-9 A-Z\*\.\/-]{2,}|[A-Z][0-9 A-Z\*\.\/-]{2,}$)/
      }
      find_slices
    end
    def find_slices
      @annotated_lines = []
      @lines.each do |line, index|
        @regex.keys.each do | part |
          @lines.each_with_index do |line, index|
            if (@regex[part] =~ line)
              @slices[part] << index
              line.prepend(part.to_s, " - ")
            end
          end
          @slices[part] = @slices[part].slice_when{|prev,cur| cur != prev + 1}.to_a
          @slices[part].reject!{|a| a.size < 4}
          @sizes[part] = @slices[part].map{|sub_a| sub_a.size}
        end
      end
    end
    def parse
      puts @slices
      puts @sizes
    end
    def result
      @lines.join("\n")
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
      f = File.open(filename)
      lines = f.readlines

      converter = Converter.new(lines: lines,filename: filename, write_header: write_header)
      converter.parse
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
