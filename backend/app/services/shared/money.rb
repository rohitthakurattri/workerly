module Shared
  # Money is integer minor units plus an ISO currency code; nothing assumes INR.
  module Money
    module_function

    MINOR_DIGITS = Hash.new(2).merge("JPY" => 0).freeze
    SYMBOLS = { "INR" => "₹" }.freeze

    def to_h(minor, currency) = { minor: minor.to_i, currency: }

    # "₹1,999", "₹1,00,000.50" (Indian digit grouping for INR), for notifications and SMS.
    def format(minor, currency)
      digits = MINOR_DIGITS[currency]
      major, fraction = minor.to_i.abs.divmod(10**digits)
      grouped = currency == "INR" ? indian_group(major) : major.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      text = "#{SYMBOLS.fetch(currency, "#{currency} ")}#{grouped}"
      text += ".#{fraction.to_s.rjust(digits, '0')}" if fraction.positive?
      minor.negative? ? "-#{text}" : text
    end

    def indian_group(n)
      s = n.to_s
      return s if s.length <= 3

      head, tail = s[0...-3], s[-3..]
      "#{head.reverse.scan(/\d{1,2}/).join(',').reverse},#{tail}"
    end
  end
end
