require "test_helper"

class Rag::MetricsTest < ActiveSupport::TestCase
  test "initializes with empty phases" do
    metrics = Rag::Metrics.new
    assert_empty metrics.phases
  end

  test "tracks a phase with latency" do
    metrics = Rag::Metrics.new
    metrics.start_phase("test_phase")
    sleep 0.01 # 10ms
    metrics.end_phase

    assert metrics.phases.key?("test_phase")
    assert metrics.phases["test_phase"][:latency_ms] >= 10
  end

  test "adds tokens to a phase" do
    metrics = Rag::Metrics.new
    metrics.start_phase("test_phase")
    metrics.add_tokens("test_phase", 100, 50)
    metrics.end_phase

    assert_equal 100, metrics.phases["test_phase"][:input_tokens]
    assert_equal 50, metrics.phases["test_phase"][:output_tokens]
    assert_equal 150, metrics.phases["test_phase"][:total_tokens]
  end

  test "accumulates tokens across multiple calls" do
    metrics = Rag::Metrics.new
    metrics.start_phase("test_phase")
    metrics.add_tokens("test_phase", 100, 50)
    metrics.add_tokens("test_phase", 100, 50)
    metrics.end_phase

    assert_equal 200, metrics.phases["test_phase"][:input_tokens]
    assert_equal 100, metrics.phases["test_phase"][:output_tokens]
    assert_equal 300, metrics.phases["test_phase"][:total_tokens]
  end

  test "tracks multiple phases independently" do
    metrics = Rag::Metrics.new

    metrics.start_phase("phase_1")
    sleep 0.01
    metrics.add_tokens("phase_1", 50, 25)
    metrics.end_phase

    metrics.start_phase("phase_2")
    sleep 0.01
    metrics.add_tokens("phase_2", 100, 75)
    metrics.end_phase

    assert_equal 50, metrics.phases["phase_1"][:input_tokens]
    assert_equal 100, metrics.phases["phase_2"][:input_tokens]
    assert metrics.phases["phase_1"][:latency_ms] >= 10
    assert metrics.phases["phase_2"][:latency_ms] >= 10
  end

  test "summary calculates totals correctly" do
    metrics = Rag::Metrics.new

    metrics.start_phase("phase_1")
    metrics.add_tokens("phase_1", 100, 50)
    sleep 0.01
    metrics.end_phase

    metrics.start_phase("phase_2")
    metrics.add_tokens("phase_2", 100, 50)
    sleep 0.01
    metrics.end_phase

    summary = metrics.summary

    assert_equal 200, summary[:total_input_tokens]
    assert_equal 100, summary[:total_output_tokens]
    assert_equal 300, summary[:total_tokens]
    assert summary[:total_latency_ms] >= 20
  end

  test "summary includes phases breakdown" do
    metrics = Rag::Metrics.new
    metrics.start_phase("phase_1")
    metrics.add_tokens("phase_1", 50, 25)
    metrics.end_phase

    summary = metrics.summary

    assert summary[:phases].key?("phase_1")
    assert_equal 50, summary[:phases]["phase_1"][:input_tokens]
    assert_equal 25, summary[:phases]["phase_1"][:output_tokens]
  end
end
