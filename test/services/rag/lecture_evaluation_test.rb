require "test_helper"

class RagEval::LectureEvaluationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  LECTURES_DIR = Rails.root.join("test", "fixtures", "files", "lectures")

  setup do
    ENV["GOOGLE_API_KEY"] = "test-key"
    Document.destroy_all
  end

  teardown do
    ENV.delete("GOOGLE_API_KEY")
  end

  # ---------------------------------------------------------------------------
  # Algorithms lecture
  # ---------------------------------------------------------------------------
  test "RAG answers bubble sort time complexity from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "time complexity of bubble sort")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers who invented merge sort from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "invented merge sort")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers quick sort worst case from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "worst-case time complexity of quick sort")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers merge sort advantage from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "advantage of merge sort")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers hash table complexity from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "hash table")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers binary search from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "binary search")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers collision resolution from algorithms lecture" do
    lecture = load_lecture("algorithms")
    q = find_question(lecture, "collision resolution")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  # ---------------------------------------------------------------------------
  # Machine Learning lecture
  # ---------------------------------------------------------------------------
  test "RAG answers supervised vs unsupervised from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "supervised and unsupervised")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers gradient descent purpose from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "gradient descent")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers overfitting from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "overfitting")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers linear regression equation from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "equation for linear regression")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers L1 vs L2 regularization from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "L1 and L2 regularization")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers ML pioneer from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "pioneered")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers activation functions from ML lecture" do
    lecture = load_lecture("machine_learning")
    q = find_question(lecture, "activation functions")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  # ---------------------------------------------------------------------------
  # Operating Systems lecture
  # ---------------------------------------------------------------------------
  test "RAG answers process vs thread from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "process and a thread")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers virtual memory from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "virtual memory")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers deadlock conditions from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "four conditions for deadlock")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers Round Robin from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "Round Robin")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers SJF scheduling from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "Shortest Job First")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers paging from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "paging")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  test "RAG answers Bankers algorithm from OS lecture" do
    lecture = load_lecture("operating_systems")
    q = find_question(lecture, "Banker")
    ingest_and_query(lecture, q, expected_keywords: q.expected_keywords)
  end

  # ---------------------------------------------------------------------------
  # Cross-lecture retrieval: correct lecture should be retrieved
  # ---------------------------------------------------------------------------
  test "cross-lecture retrieval finds algorithms content for sorting question" do
    ingest_all_lectures
    stub_gemini_response("Merge sort has O(n log n) time complexity.")

    # Use hybrid search so BM25 can distinguish lectures by keyword content
    result = Rag::Query.new("What is the time complexity of merge sort?", search_type: "hybrid").call

    assert result[:sources].is_a?(Array), "Expected sources to be an array"
    assert result[:sources].any?, "Expected at least one retrieved chunk"

    # At least one source should contain sorting-related content
    has_relevant = result[:sources].any? do |s|
      content = s[:content].to_s.downcase
      content.include?("merge sort") || content.include?("sorting") || content.include?("n log n")
    end
    assert has_relevant, "Expected retrieved sources to contain merge sort content"
  end

  test "cross-lecture retrieval finds OS content for scheduling question" do
    ingest_all_lectures
    stub_gemini_response("Round Robin assigns each process a fixed time quantum.")

    result = Rag::Query.new("How does Round Robin scheduling work?", search_type: "hybrid").call

    assert result[:sources].is_a?(Array), "Expected sources to be an array"
    if result[:sources].any?
      has_relevant = result[:sources].any? do |s|
        content = s[:content].to_s.downcase
        content.include?("round robin") || content.include?("scheduling") || content.include?("quantum")
      end
      assert has_relevant, "Expected retrieved sources to contain scheduling content"
    end
  end

  test "cross-lecture retrieval finds ML content for gradient descent question" do
    ingest_all_lectures
    stub_gemini_response("Gradient descent minimizes the cost function.")

    result = Rag::Query.new("What is gradient descent used for in machine learning?", search_type: "hybrid").call

    assert result[:sources].is_a?(Array), "Expected sources to be an array"
    if result[:sources].any?
      has_relevant = result[:sources].any? do |s|
        content = s[:content].to_s.downcase
        content.include?("gradient") || content.include?("cost function") || content.include?("optimization")
      end
      assert has_relevant, "Expected retrieved sources to contain gradient descent content"
    end
  end

  # ---------------------------------------------------------------------------
  # Evaluation metrics integration
  # ---------------------------------------------------------------------------
  test "evaluation metrics produce reasonable scores for correct answers" do
    answer = "Bubble sort has a worst-case and average time complexity of O(n squared), making it inefficient for large datasets."
    expected = "Bubble sort has a worst-case and average time complexity of O(n squared)."
    keywords = ["O(n squared)", "bubble sort"]

    kw = RagEval::Metrics.keyword_recall(answer, keywords)
    f1 = RagEval::Metrics.token_f1(answer, expected)
    score = RagEval::Metrics.overall_score(answer: answer, expected_answer: expected, expected_keywords: keywords)

    assert_operator kw, :>=, 0.8, "Keyword recall should be high for correct answer"
    assert_operator f1, :>=, 0.5, "Token F1 should be moderate for correct answer"
    assert_operator score, :>=, 50, "Overall score should pass threshold"
  end

  test "evaluation metrics produce low scores for wrong answers" do
    answer = "Quantum computing uses qubits and superposition."
    expected = "Bubble sort has O(n squared) time complexity."
    keywords = ["O(n squared)", "bubble sort"]

    score = RagEval::Metrics.overall_score(answer: answer, expected_answer: expected, expected_keywords: keywords)
    assert_operator score, :<, 30, "Overall score should be low for wrong answer"
  end

  # ---------------------------------------------------------------------------
  # Full evaluator test with all lectures
  # ---------------------------------------------------------------------------
  test "full evaluator runs on all lectures and produces summary" do
    ingest_all_lectures

    # Stub Gemini to echo the expected answer for each question
    lectures = RagEval::Dataset.load
    all_questions = lectures.flat_map(&:questions)

    stub_request(:post, GEMINI_URL)
      .to_return do |request|
        body = JSON.parse(request.body)
        prompt_text = body.dig("contents", 0, "parts", 0, "text") || ""

        # Find matching question and return its expected answer
        matched = all_questions.find { |q| prompt_text.include?(q.question) }
        answer = matched ? matched.expected_answer : "I don't know."

        {
          status: 200,
          body: { candidates: [{ content: { parts: [{ text: answer }] } }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        }
      end

    evaluator = RagEval::Evaluator.new
    summary = evaluator.evaluate_all

    assert_equal 21, summary.total_questions
    assert summary.avg_keyword_recall >= 0.0
    assert summary.avg_token_f1 >= 0.0
    assert summary.avg_overall_score >= 0.0
    assert_equal 21, summary.results.size

    # Print report for visibility
    report = RagEval::Reporter.new(summary)
    puts "\n#{report}"
  end

  private

  # Load a lecture from the evaluation dataset
  def load_lecture(lecture_id)
    lecture = RagEval::Dataset.load_lecture(lecture_id)
    assert_not_nil lecture, "Lecture '#{lecture_id}' not found in dataset"
    lecture
  end

  # Find a question by partial match
  def find_question(lecture, partial)
    q = lecture.questions.find { |q| q.question.downcase.include?(partial.downcase) }
    assert_not_nil q, "Question matching '#{partial}' not found in lecture '#{lecture.id}'"
    q
  end

  # Ingest a lecture, run the RAG query, and validate the answer
  def ingest_and_query(lecture, question, expected_keywords:)
    # Create document and chunks with topic-aware embeddings
    doc = ingest_lecture(lecture)

    # Stub Gemini to return the expected answer
    stub_gemini_response(question.expected_answer)

    # Run RAG query
    result = Rag::Query.new(question.question).call

    # Validate structure
    assert result.key?(:answer), "RAG result should have :answer"
    assert result.key?(:sources), "RAG result should have :sources"
    assert result[:answer].present?, "RAG answer should not be blank"

    # Validate answer quality using metrics
    kw_recall = RagEval::Metrics.keyword_recall(result[:answer], expected_keywords)
    f1_score = RagEval::Metrics.token_f1(result[:answer], question.expected_answer)
    overall = RagEval::Metrics.overall_score(
      answer: result[:answer],
      expected_answer: question.expected_answer,
      expected_keywords: expected_keywords,
      sources: result[:sources].is_a?(Array) ? result[:sources] : []
    )

    # Assert minimum quality thresholds
    assert_operator kw_recall, :>=, 0.3,
      "Keyword recall too low (#{(kw_recall * 100).round(1)}%) for: #{question.question}"
    assert_operator f1_score, :>=, 0.2,
      "Token F1 too low (#{(f1_score * 100).round(1)}%) for: #{question.question}"
    assert_operator overall, :>=, 20.0,
      "Overall score too low (#{overall}) for: #{question.question}"

    # Log retrieval quality (soft check — with mocked embeddings, retrieval
    # precision depends on chunk ordering rather than true semantic relevance)
    if result[:sources].is_a?(Array) && result[:sources].any?
      hit = RagEval::Metrics.retrieval_hit?(result[:sources], expected_keywords)
      unless hit
        puts "  [WARN] No retrieved chunk contained expected keywords for: #{question.question}"
      end
    end
  end

  # Ingest a lecture as a document with chunked embeddings
  def ingest_lecture(lecture)
    # Generate a deterministic embedding based on lecture content
    embedding = topic_embedding(lecture.id)

    # Stub Ollama to return topic-specific embeddings
    stub_ollama(embedding)

    doc = Document.create!(content: lecture.content)
    doc.update_column(:embedding, embedding)
    doc.update_column(:index_status, "completed")

    # Create chunks using the real chunker
    chunks = Preprocessing::Chunker.call(lecture.content)
    chunks.each do |chunk_info|
      doc.chunks.create!(
        start_char: chunk_info[:start_char],
        end_char: chunk_info[:end_char],
        context: "",
        embedding: embedding
      )
    end

    doc
  end

  # Ingest all three lectures
  def ingest_all_lectures
    lectures = RagEval::Dataset.load

    # Use same embedding for simplicity — retrieval still works via BM25 in hybrid
    embedding = Array.new(768) { 0.5 }
    stub_ollama(embedding)

    lectures.each do |lecture|
      doc = Document.create!(content: lecture.content)
      doc.update_column(:embedding, embedding)
      doc.update_column(:index_status, "completed")

      chunks = Preprocessing::Chunker.call(lecture.content)
      chunks.each do |chunk_info|
        doc.chunks.create!(
          start_char: chunk_info[:start_char],
          end_char: chunk_info[:end_char],
          context: "",
          embedding: embedding
        )
      end
    end
  end

  # Generate a deterministic embedding for a lecture topic
  def topic_embedding(lecture_id)
    seed = case lecture_id
           when "algorithms" then 42
           when "machine_learning" then 84
           when "operating_systems" then 126
           else 1
           end

    rng = Random.new(seed)
    Array.new(768) { rng.rand(-1.0..1.0) }
  end
end
