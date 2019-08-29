module Helpers
  def self.FormatNumber(number)
    return number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
