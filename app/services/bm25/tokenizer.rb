module Bm25
  class Tokenizer
    STOP_WORDS = %w[
      a an the is are was were be been being have has had do does did
      will would could should may might shall can of in on at to for
      with by from as into through during before after above below
      between out off over under again further then once here there
      when where why how all both each few more most other some such
      no nor not only own same so than too very just i me my we our
      you your he she it its they them their what which who this that
      these those am and but or if while s t re ve ll d m
    ].to_set.freeze

    # Returns an array of lowercased, filtered tokens from the given text.
    def self.call(text)
      text.to_s
          .downcase
          .gsub(/[^a-z0-9\s]/, " ")
          .split
          .reject { |token| token.length < 2 || STOP_WORDS.include?(token) }
    end
  end
end
