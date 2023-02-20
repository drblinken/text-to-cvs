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
  def to_log
    entry_id = entry ? entry.id : "+"
    "#{x}:#{y}-#{part}/#{slice}/#{slice_i}/#{entry_id}-- #{line}"
  end

end
