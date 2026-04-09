module Rag
  class Metrics
    attr_reader :phases

    def initialize
      @phases = {}
      @current_phase = nil
    end

    def start_phase(name)
      @current_phase = name
      @phases[name] ||= {
        start_time: nil,
        end_time: nil,
        latency_ms: 0,
        input_tokens: 0,
        output_tokens: 0,
        total_tokens: 0
      }
      @phases[name][:start_time] = Time.now
    end

    def end_phase
      return unless @current_phase

      @phases[@current_phase][:end_time] = Time.now
      @phases[@current_phase][:latency_ms] = (
        (@phases[@current_phase][:end_time] - @phases[@current_phase][:start_time]) * 1000
      ).round(2)
      @current_phase = nil
    end

    def add_tokens(phase_name, input_tokens, output_tokens)
      @phases[phase_name] ||= default_phase
      @phases[phase_name][:input_tokens] += input_tokens.to_i
      @phases[phase_name][:output_tokens] += output_tokens.to_i
      @phases[phase_name][:total_tokens] = (
        @phases[phase_name][:input_tokens] + @phases[phase_name][:output_tokens]
      )
    end

    def summary
      {
        phases: @phases.transform_values { |phase| summarize_phase(phase) },
        total_latency_ms: total_latency,
        total_input_tokens: total_input_tokens,
        total_output_tokens: total_output_tokens,
        total_tokens: total_tokens
      }
    end

    private

    def summarize_phase(phase)
      {
        latency_ms: phase[:latency_ms],
        input_tokens: phase[:input_tokens],
        output_tokens: phase[:output_tokens],
        total_tokens: phase[:total_tokens]
      }
    end

    def default_phase
      {
        start_time: nil,
        end_time: nil,
        latency_ms: 0,
        input_tokens: 0,
        output_tokens: 0,
        total_tokens: 0
      }
    end

    def total_latency
      @phases.values.sum { |phase| phase[:latency_ms] }.round(2)
    end

    def total_input_tokens
      @phases.values.sum { |phase| phase[:input_tokens] }
    end

    def total_output_tokens
      @phases.values.sum { |phase| phase[:output_tokens] }
    end

    def total_tokens
      total_input_tokens + total_output_tokens
    end
  end
end
