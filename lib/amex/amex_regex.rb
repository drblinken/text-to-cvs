require './lib/amex/line.rb'
module AmexRegexp

  # regexes to identify the main information parts
  # Saldodeslaufenden Monats
  # text_re = '[A-Z][0-9 A-Z*.\/\+-]{2,}'
  #
  text_re = '[A-Z][(0-9 A-Za-zäüö*.\/\+-]{2,}'
  text_re_upper_only = '[A-Z][(0-9 A-Z*.\/\+-]{2,}'

  def self.at_start_or_end(text_re)
    Regexp.new("(^#{text_re}|#{text_re}$)")
  end

  TEXT_RE_CAPS = at_start_or_end(text_re_upper_only)
  TEXT_RE_BOTH = at_start_or_end(text_re)

  AMREGEX = { date: /((\d\d\.\d\d)\s?(\d\d\.\d\d))|(CR)/,
              amount: /^(Hinweise zu Ihrer Kartenabrechnung)?(([\.\d]+,\d\d)|(Saldo\s?des\s?laufenden Monats|Sonstige Transaktionen))/,
              text: TEXT_RE_BOTH
  }

  def re_match(which, str)
    if :text == which
      extract_text(str)
    else
      AMREGEX[which].match(str)
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
      Line.new(line: content, x: m[1], y: m[2])
    else
      nil
    end
  end

  PAYMENT_REGEX = /ZAHLUNG ERHALTEN. BESTEN DANK./

  def is_payment(str)
    PAYMENT_REGEX =~ str
  end

  SUMMARY_REGEX = /([\.\d]+,\d\d) ?\- ?([\.\d]+,\d\d) ?\+ ?([\.\d]+,\d\d) ?= ?([\.\d]+,\d\d)/

  def summary(str)
    m = SUMMARY_REGEX.match(str)
    return nil unless m
    # saldo letzter monat, gutschriften, belastungen, neuer salso
    # gutschriften, belastungen
    [m[2], m[3]]
  end

  def count_lower(str)
    str.scan(/[a-z]/).size
  end

  def has_more_capital_letters(str)
    upper = str.scan(/[A-Z]/).size
    lower = count_lower(str)
    upper > lower
  end

  def extract_text(str)
    return nil if /xxxx-xxxxxx.*Seite/.match(str)
    m_both = TEXT_RE_BOTH.match(str)
    m_caps = TEXT_RE_CAPS.match(str)
    return nil unless m_both
    text_both = m_both[1]
    return text_both if m_caps && (text_both == m_caps[1])
    return text_both if count_lower(text_both) < 4
    # return nil if m_caps && /xxxx-xxxxxx.*Seite/.match(text_both[1])
    return text_both if has_more_capital_letters(text_both)
    return nil if m_caps && ["EUR","HRB 112342","US D"].include?(m_caps[1])
    # return nil if /xxxx-xxxxxx.*Seite/.match(m_caps[1])
    return m_caps[1] if m_caps
    return nil
  end
end
