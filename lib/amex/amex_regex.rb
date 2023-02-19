require './lib/amex/line.rb'
module AmexRegexp

  # regexes to identify the main information parts
  # Saldodeslaufenden Monats
  text_re = '[A-Z][0-9 A-Z*.\/\+-]{2,}'
  at_start_or_end = "(^#{text_re}|#{text_re}$)"
  AMREGEX = { date: /((\d\d\.\d\d)\s?(\d\d\.\d\d))|(CR)/,
            amount: /^(Hinweise zu Ihrer Kartenabrechnung)?(([\.\d]+,\d\d)|(Saldo\s?des\s?laufenden Monats))/,
            text: Regexp.new(at_start_or_end)
  }



  def re_match(which,str)
    AMREGEX[which].match(str)
  end
  def is_amount_noise(str, logger = nil)
    m = AMREGEX[:amount].match(str)
    is_noise = !m[4].nil?
    logger.debug("---noise #{is_noise}: #{m.inspect} --#{str}") if logger
    is_noise
  end

  def re_extract_amount(str)
    m = AMREGEX[:amount].match(str)
    amount_part = m[2]
    parse_amount(amount_part)
  end

  def parse_amount(amount)
    amount.gsub('.', '').gsub(',', '.').to_f
  end


  #@@prefix_re = /(\d{4}\.\d):(\d{4}\.\d)-- /
  PREFIX_RE = /^(\d{4}\.\d):(\d{4}\.\d)--( (.*))?$/
  def parse_prefix(line)
    m = PREFIX_RE.match(line)
    if m
      content = m[4] || ""
      Line.new( line: content, x: m[1], y: m[2])
    else
      nil
    end
  end

end