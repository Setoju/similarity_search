module Bm25
  # Okapi BM25 ranking index.
  #
  # Usage:
  #   corpus = [{ id: 1, text: "..." }, { id: 2, text: "..." }]
  #   index  = Bm25::Index.new(corpus)
  #   index.score("my query", top: 10)
  #   #=> [{ id: 1, score: 3.14 }, { id: 2, score: 1.59 }, ...]
  #
  # The corpus items can use any :id value (e.g. ActiveRecord id or array index).
  class Index
    K1 = 1.5  # term-frequency saturation parameter (controls how much extra occurrences of a term contribute to relevance)
    B  = 0.75 # length normalisation parameter

    # @param corpus [Array<Hash>] each element must have :id and :text keys
    def initialize(corpus)
      @corpus = corpus
      @n = corpus.size
      build_index
    end

    # Score every document in the corpus against +query+ and return ranked
    # results in descending order.
    #
    # @param query [String]
    # @param top   [Integer, nil] number of results to return (nil = all)
    # @return [Array<Hash>] each element has :id and :score
    def score(query, top: nil)
      terms = Bm25::Tokenizer.call(query)
      return [] if terms.empty? || @n.zero?

      scores = Hash.new(0.0)

      terms.uniq.each do |term|
        next unless @inverse_doc_freq.key?(term)

        idf = @inverse_doc_freq[term]
        @postings[term].each do |idx|
          tf = @term_frequency[idx][term].to_f
          dl = @doc_lengths[idx]
          num = tf * (K1 + 1)
          den = tf + K1 * (1 - B + B * dl.to_f / @avgdl)
          scores[idx] += idf * num / den
        end
      end

      ranked = scores.map { |idx, sc| { id: @corpus[idx][:id], score: sc } }
      ranked.sort_by! { |r| -r[:score] }
      top ? ranked.first(top) : ranked
    end

    # Return the total number of documents in the index.
    def size
      @n
    end

    private

    def build_index
      @term_frequency = [] # Array<Hash<term, count>> term frequency for each document
      @doc_lengths = [] # Array<Integer> (doc lengths) number of terms in each document
      @postings = Hash.new { |h, k| h[k] = [] } # term -> [doc_idx, ...]

      @corpus.each_with_index do |item, idx|
        tokens = Bm25::Tokenizer.call(item[:text])
        @doc_lengths << tokens.size

        term_freq = Hash.new(0)
        tokens.each { |t| term_freq[t] += 1 }
        @term_frequency << term_freq

        term_freq.each_key { |t| @postings[t] << idx }
      end

      total_tokens = @doc_lengths.sum
      @avgdl = @n.positive? ? total_tokens.to_f / @n : 1.0 # average document length across the corpus

      @inverse_doc_freq = {}
      @postings.each do |term, posting|
        df = posting.size
        # if term appears in many documents, it is less informative, so idf is lower
        @inverse_doc_freq[term] = Math.log((@n - df + 0.5) / (df + 0.5) + 1)
      end
    end
  end
end
