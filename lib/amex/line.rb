# frozen_string_literal: true

Line = Struct.new(:line_no, :line, :x, :y, :part, :slice, :slice_i, :entry, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.part = []
  end
  def to_log
    entry_id = entry ? entry.id : "+"
    "#{x}:#{y}-#{part}/#{slice}/#{slice_i}/#{entry_id}-- #{line}"
  end
end
