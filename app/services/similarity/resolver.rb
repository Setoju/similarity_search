module Similarity
  class Resolver
    STRATEGIES = {
      'cosine' => Similarity::Cosine,
      'euclidean' => Similarity::Euclidean
    }.freeze

    def self.call(type = 'cosine')
      STRATEGIES[type.to_s] || STRATEGIES['cosine']
    end
  end
end