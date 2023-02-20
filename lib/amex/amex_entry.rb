# frozen_string_literal: true

AmexEntry = Struct.new(:id, :date, :value_date, :text, :amount, :cr, :lines, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.lines = []
  end
  def amount_s
    amount.round(2).to_s('F').gsub(".",",")
  end
  def self.cvs_header
    members.append("slice")
  end
  def quote(str)
    return "\"#{str}\""
  end

  def cvs_values
    slice = lines.map{ |l| "#{l.slice}/#{l.slice_i}"}.uniq.join(", ")
    [id, date, value_date, quote(text), amount_s , cr, quote(lines.map(&:line_no)) , quote(slice) ]
  end
end
