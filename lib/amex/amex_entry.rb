# frozen_string_literal: true

AmexEntry = Struct.new(:id, :date, :value_date, :text, :amount, :saldo, :cr, :lines, keyword_init: true) do
  def initialize(*args)
    super(*args)
    self.saldo = false
    self.lines = []
  end
  def amount_sf
    amount.round(2).to_s('F').gsub(".",",")
  end
  def self.cvs_header
    members.append("slice")
  end
  def quote(str)
    return "\"#{str}\""
  end

  def cvs_values
    slice = lines.map{ |l| "#{l.slice}_#{l.slice_i}_#{id}"}.uniq.join(", ")
    [id, date, value_date, quote(text), amount_sf , saldo, cr, quote(lines.map(&:line_no)) , quote(slice) ]
  end
end
