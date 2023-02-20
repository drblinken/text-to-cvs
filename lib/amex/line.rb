# frozen_string_literal: true
Hint = Struct.new(:slice,:slice_i,:entry_id, keyword_init:true) do
  def to_s
    "#{slice}/#{slice_i}/#{entry_id}"
  end
end
Line = Struct.new(:line_no, :line, :x, :y, :part, :slice, :slice_i, :entry, :hint, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.part = []
  end
  def hint_log
    hint ? "--#{hint.to_s}" : ""
  end
  def check_text
    return "" if entry.nil?
    return "" if !part.include?(:text)
    return "" if line == entry.text
    return "" if line == entry.text + "www.americanexpress.de"
    #STDERR.puts("Text complete? [#{line}||#{entry.text}")
    "--EXTRACTED_TEXT--#{entry.text}"
  end
  def to_log
    entry_id = entry ? entry.id : "+"
    "#{x}:#{y}-#{part}-#{slice}_#{slice_i}_#{entry_id}-- #{line}#{check_text}"
  end

end
