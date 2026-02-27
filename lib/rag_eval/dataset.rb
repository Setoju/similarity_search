require "yaml"

module RagEval
  class Dataset
    LECTURES_DIR = Rails.root.join("test", "fixtures", "files", "lectures")
    DATASET_FILE = LECTURES_DIR.join("evaluation_dataset.yml")

    Lecture = Struct.new(:id, :file, :source, :content, :questions, keyword_init: true)
    Question = Struct.new(:question, :expected_answer, :expected_keywords, :topic, keyword_init: true)

    def self.load
      new.load
    end

    def load
      raw = YAML.load_file(DATASET_FILE)
      raw["lectures"].map { |lecture_data| build_lecture(lecture_data) }
    end

    def self.load_lecture(lecture_id)
      new.load.find { |l| l.id == lecture_id.to_s }
    end

    private

    def build_lecture(data)
      content = File.read(LECTURES_DIR.join(data["file"]))
      questions = data["questions"].map do |q|
        Question.new(
          question: q["question"],
          expected_answer: q["expected_answer"],
          expected_keywords: q["expected_keywords"] || [],
          topic: q["topic"]
        )
      end

      Lecture.new(
        id: data["id"],
        file: data["file"],
        source: data["source"],
        content: content,
        questions: questions
      )
    end
  end
end
