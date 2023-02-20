require './lib/amex/line.rb'
require 'bigdecimal'
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
  RE_CR = /CR/
  TEXT_RE_CAPS = at_start_or_end(text_re_upper_only)
  TEXT_RE_BOTH = at_start_or_end(text_re)
  SALDO_SONSTIGE_RE = /(Saldo\s*sonstige\s*Transaktionen)/

  amount_noise = '(Saldo\s?des\s?laufenden Monats|CR|^Sonstige Transaktionen)'
  amount_specials = '^(Saldosonstige Transaktionen |Hinweise zu Ihrer Kartenabrechnung)'
  amount_regex_str = format('%s?(([\.\d]+,\d\d)|%s)',amount_specials,amount_noise)
  amount_re = Regexp.new(amount_regex_str)

  str_old = "^(Hinweise zu Ihrer Kartenabrechnung)?(([\.\d]+,\d\d)|(Saldo\s?des\s?laufenden Monats|CR|Sonstige Transaktionen))"

    AMREGEX = { date: /((\d\d\.\d\d)\s?(\d\d\.\d\d))|(CR)($|Seite)/,
              amount: amount_re,
                # amount: /^(Hinweise zu Ihrer Kartenabrechnung)?(([\.\d]+,\d\d)|(Saldo\s?des\s?laufenden Monats|CR))/,
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
    throw Exception.new("should match amount regex: #{str}") unless m
    is_noise = !m[4].nil?
    logger.debug("---noise #{is_noise}: #{m.inspect} --#{str}") if logger
    is_noise = is_noise || SUMMARY_REGEX.match(str)
    is_noise = is_noise || /Saldodeslaufenden Monatsfür/.match(str)
    is_noise
  end

  def re_extract_amount(str)
    m = AMREGEX[:amount].match(str)
    amount_part = m[2]
    parse_amount(amount_part)
  end

  def parse_amount(amount)
    str = amount.gsub('.', '').gsub(',', '.')
    BigDecimal(str)
  end

  xy = '(\d{4}\.\d)'
  d = '(\d?\d)'
  xy_part = format('^%s:%s',xy,xy)
  slice_info_part = format('(--%s\/%s\/%s)?',d,d,d)
  prefix_str = format('%s%s--( (.*))?$',xy_part,slice_info_part)
  PREFIX_RE = Regexp.new(prefix_str)


  # Match 5
  # 1.	2014.4
  # 2.	2163.2
  # 3.	--1/12/19
  # 4.	1
  # 5.	12
  # 6.	19
  # 7.	CR
  # 8.	CR
  def extract_prefix_hint(m)
    return nil unless m[3]
    Hint.new(slice: m[4].to_i,slice_i: m[5].to_i,entry_id: m[6].to_i)
  end
  def parse_prefix(line)
    m = PREFIX_RE.match(line)
    if m
      content = m[8] || ""
      x = m[1] || "000000"
      y = m[2] || "000000"
      hint = extract_prefix_hint(m)
      Line.new(line: content, x: m[1], y: m[2], hint: hint)
    else
      nil
    end
  end

  PAYMENT_REGEX = /ZAHLUNG ERHALTEN. BESTEN DANK.|Saldosonstige Transaktionen/

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
    return nil if /CRSeite\dvon\d/.match(str)
    return str if /(DorintGmbHDorintHoteBremen|OnlineStoreHUGOBOSSMetzingen)/.match(str)
    return nil if /(xxxx-xxxxxx.*Seite|EIGENVERTRIEB C|Flugstrecke|^Nach)/.match(str)
    if m = SALDO_SONSTIGE_RE.match(str)
      return m[1]
    end
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

  def is_date(line)
    AMREGEX[:date].match(line)
  end
  def date_extract_cr(line)
    AMREGEX[:date].match(line)[4]
    #date: /((\d\d\.\d\d)\s?(\d\d\.\d\d))|(CR)($|Seite)/,
  end

  def is_cr(line)
    RE_CR.match(line)
  end
end
