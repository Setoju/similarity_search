module Preprocessing
  class Normalizer
    def self.call(text)
      text.downcase.strip.gsub(/\s+/, " ")
    end
  end
end