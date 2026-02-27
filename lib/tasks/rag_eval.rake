require "rag_eval/dataset"
require "rag_eval/metrics"
require "rag_eval/evaluator"
require "rag_eval/reporter"

namespace :rag_eval do
  desc "Run RAG evaluation against real Ollama + Gemini services (requires running servers)"
  task run: :environment do
    puts "Loading lecture dataset..."
    lectures = RagEval::Dataset.load
    puts "Loaded #{lectures.size} lectures with #{lectures.sum { |l| l.questions.size }} total questions"
    puts ""

    # Ingest lectures as documents
    puts "Ingesting lectures..."
    lectures.each do |lecture|
      existing = Document.where("content LIKE ?", "#{lecture.content[0..100]}%")
      if existing.any?
        puts "  [#{lecture.id}] Already ingested (#{existing.first.index_status})"
        next
      end

      doc = Document.create!(content: lecture.content)
      puts "  [#{lecture.id}] Created document ##{doc.id} - waiting for embedding..."
    end

    # Wait for documents to be processed
    puts ""
    puts "Waiting for document indexing to complete..."
    60.times do |i|
      pending = Document.pending_or_processing.count
      break if pending.zero?
      print "\r  #{pending} document(s) still processing... (#{i + 1}s)"
      sleep 1
    end
    puts "\n"

    completed = Document.completed.count
    failed = Document.failed.count
    puts "Indexing complete: #{completed} completed, #{failed} failed"
    puts ""

    if failed.positive?
      puts "WARNING: #{failed} document(s) failed indexing. Results may be incomplete."
      puts ""
    end

    # Run evaluation
    search_type = ENV.fetch("SEARCH_TYPE", "hybrid")
    rerank = ENV.fetch("RERANK", "false") == "true"

    puts "Running evaluation (search_type=#{search_type}, rerank=#{rerank})..."
    puts ""

    evaluator = RagEval::Evaluator.new(search_type: search_type, rerank: rerank)
    summary = evaluator.evaluate_all

    # Print report
    report = RagEval::Reporter.new(summary)
    puts report

    # Save report to file
    report_path = Rails.root.join("tmp", "reports", "rag_eval_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt")
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, report.to_s)
    puts "\nReport saved to: #{report_path}"

    # Exit with error code if pass rate is below threshold
    pass_rate = summary.total_questions.positive? ? (summary.passed.to_f / summary.total_questions * 100) : 0
    if pass_rate < 50
      puts "\nFAILED: Pass rate #{pass_rate.round(1)}% is below 50% threshold"
      exit 1
    else
      puts "\nPASSED: Pass rate #{pass_rate.round(1)}%"
    end
  end

  desc "Run RAG evaluation for a single lecture"
  task :lecture, [:lecture_id] => :environment do |_t, args|
    lecture_id = args[:lecture_id] || "algorithms"
    lecture = RagEval::Dataset.load_lecture(lecture_id)

    unless lecture
      puts "Lecture '#{lecture_id}' not found. Available: algorithms, machine_learning, operating_systems"
      exit 1
    end

    puts "Evaluating lecture: #{lecture.id} (#{lecture.questions.size} questions)"
    puts "Source: #{lecture.source}"
    puts ""

    evaluator = RagEval::Evaluator.new(search_type: ENV.fetch("SEARCH_TYPE", "hybrid"))
    results = evaluator.evaluate_lecture(lecture)

    results.each_with_index do |result, idx|
      status = result.passed ? "PASS" : "FAIL"
      puts "#{idx + 1}. [#{status}] #{result.question}"
      puts "   Expected: #{result.expected_answer[0..80]}..."
      puts "   RAG:      #{result.rag_answer[0..80]}..."
      puts "   Score:    #{result.overall_score}/100 (KW: #{(result.keyword_recall * 100).round(1)}%, F1: #{(result.token_f1 * 100).round(1)}%)"
      puts ""
    end

    passed = results.count(&:passed)
    puts "Results: #{passed}/#{results.size} passed"
  end

  desc "List all questions in the evaluation dataset"
  task list: :environment do
    lectures = RagEval::Dataset.load
    lectures.each do |lecture|
      puts "#{lecture.id} (#{lecture.source}):"
      lecture.questions.each_with_index do |q, idx|
        puts "  #{idx + 1}. #{q.question}"
        puts "     Expected: #{q.expected_answer[0..70]}..."
        puts "     Keywords: #{q.expected_keywords.join(', ')}"
      end
      puts ""
    end
    puts "Total: #{lectures.sum { |l| l.questions.size }} questions across #{lectures.size} lectures"
  end
end
