module Similarity
  class Cosine
    def self.call(vec_a, vec_b)
      return 0.0 unless vec_a.is_a?(Array) && vec_b.is_a?(Array)
      return 0.0 if vec_a.empty? || vec_b.empty?
      
      unless vec_a.length == vec_b.length
        Rails.logger.warn "Vector dimension mismatch: #{vec_a.length} vs #{vec_b.length}"
        return 0.0
      end
      
      dot = vec_a.zip(vec_b).sum { |x, y| x.to_f * y.to_f }
      
      norm_a = Math.sqrt(vec_a.sum { |x| x.to_f ** 2 })
      norm_b = Math.sqrt(vec_b.sum { |x| x.to_f ** 2 })
      
      return 0.0 if norm_a.zero? || norm_b.zero?
      
      similarity = dot / (norm_a * norm_b)
      
      # Clamp to valid range [-1, 1]
      [[-1.0, similarity].max, 1.0].min
    end
  end
end
