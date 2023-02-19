require './lib/amex/line.rb'
module AmexRegexp

  # regexes to identify the main information parts
  # Saldodeslaufenden Monats
  # text_re = '[A-Z][0-9 A-Z*.\/\+-]{2,}'
  text_re = '[A-Z][(0-9 A-Za-z*.\/\+-]{2,}'
  at_start_or_end = "(^#{text_re}|#{text_re}$)"
  AMREGEX = { date: /((\d\d\.\d\d)\s?(\d\d\.\d\d))|(CR)/,
            amount: /^(Hinweise zu Ihrer Kartenabrechnung)?(([\.\d]+,\d\d)|(Saldo\s?des\s?laufenden Monats|Sonstige Transaktionen))/,
            text: Regexp.new(at_start_or_end)
  }



  def re_match(which,str)
    match = AMREGEX[which].match(str)
    return nil unless match
    if :text == which
      is_text(str) ? match : nil
    else
      match
    end
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

  PAYMENT_REGEX = /ZAHLUNG ERHALTEN. BESTEN DANK./
  def is_payment(str)
    PAYMENT_REGEX =~ str
  end




  def has_more_capital_letters(str)
    upper =   str.scan(/[A-Z]/).size
    lower = str.scan(/[a-z]/).size
    upper > lower
  end

  def is_text(str)
    has_more_capital_letters(str)
  end
end