module Similarity
  class Euclidean
    def self.call(vec_a, vec_b)
      return 0.0 unless vec_a.is_a?(Array) && vec_b.is_a?(Array)
      return 0.0 if vec_a.empty? || vec_b.empty?
            
      unless vec_a.length == vec_b.length
        Rails.logger.warn "Vector dimension mismatch: #{vec_a.length} vs #{vec_b.length}"
        return 0.0
      end
            
      distance = Math.sqrt(vec_a.zip(vec_b).sum { |x, y| (x.to_f - y.to_f) ** 2 })
            
      similarity = 1.0 / (1.0 + distance)
            
      similarity
    end
  end
end