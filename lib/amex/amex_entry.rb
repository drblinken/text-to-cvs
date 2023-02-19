# frozen_string_literal: true

AmexEntry = Struct.new(:id, :date, :value_date, :text, :amount, :cr, :lines, keyword_init: true) do
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
