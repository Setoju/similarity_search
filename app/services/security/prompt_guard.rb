module Security
  # Validates that user-provided text (queries and document content) does not
  # contain prompt-injection patterns that attempt to override LLM instructions.
  #
  # Usage:
  #   guard = Security::PromptGuard.new(text)
  #   guard.safe?            # => true / false
  #   guard.detections       # => [{ name: "instruction_override", ... }, ...]
  #   guard.rejection_message # => human-readable reason or nil
  class PromptGuard
    PATTERNS = [
      { name: "instruction_override",
        pattern: /ignore\s+(all\s+)?(previous|prior|above|earlier|preceding)\s+(instructions?|prompts?|context|rules?|guidelines?)/i },
      { name: "role_hijacking",
        pattern: /you\s+are\s+(now|no\s+longer)\s+(a|an|the)?\s*\w+/i },
      { name: "system_prompt_leak",
        pattern: /(repeat|show|reveal|display|print|output)\s+(the\s+)?(exact|full|original|entire|complete)?\s*(system\s+)?(prompt|instructions?|rules?|guidelines?)/i },
      { name: "new_instruction",
        pattern: /\b(new|updated?|revised?|override)\s+(system\s+)?(instruction|prompt|directive|command|role)/i },
      { name: "context_escape",
        pattern: /(end\s+of\s+(context|instructions?|prompt|document)|<\/?(system|instruction|prompt|context)>|\[\s*\/?\s*(SYSTEM|INST|SYS|INSTRUCTION)\s*\])/i },
      { name: "roleplay",
        pattern: /\b(act\s+as|pretend\s+(to\s+be|you\s+are)|simulate|roleplay|role-play)\b/i },
      { name: "format_hijack",
        pattern: /return\s+(this|the\s+following)\s+(json|xml|html|text)\s*(instead|:)/i }
    ].freeze

    attr_reader :detections

    def initialize(text)
      @text = text.to_s
      @detections = detect
    end

    def safe?
      @detections.empty?
    end

    def rejection_message
      return nil if safe?

      "Input rejected: detected prompt injection (#{@detections.map { |d| d[:name] }.join(', ')})"
    end

    private

    def detect
      PATTERNS.each_with_object([]) do |spec, hits|
        hits << { name: spec[:name] } if @text.match?(spec[:pattern])
      end
    end
  end
end
