require "test_helper"

class Preprocessing::ChunkerTest < ActiveSupport::TestCase
  test "returns empty array for nil text" do
    assert_equal [], Preprocessing::Chunker.call(nil)
  end

  test "returns empty array for empty string" do
    assert_equal [], Preprocessing::Chunker.call("")
  end

  test "returns empty array for whitespace-only text" do
    assert_equal [], Preprocessing::Chunker.call("   ")
  end

  test "returns a single chunk for short text" do
    result = Preprocessing::Chunker.call("Hello world.")
    assert_equal 1, result.length
    assert_equal "Hello world.", result.first[:content]
    assert_equal 0, result.first[:start_char]
  end

  test "chunks include expected keys" do
    result = Preprocessing::Chunker.call("Hello world.")
    chunk = result.first
    assert chunk.key?(:content)
    assert chunk.key?(:start_char)
    assert chunk.key?(:end_char)
  end

  test "splits long text into multiple chunks at sentence boundaries" do
    sentences = (1..20).map { |i| "This is number#{i} sentence." }
    text = sentences.join(" ")
    result = Preprocessing::Chunker.call(text, chunk_size: 100, overlap: 0)

    assert result.length > 1
    result.each do |chunk|
      # Every chunk should end with sentence-ending punctuation
      assert_match(/[.!?]\z/, chunk[:content].strip,
        "Chunk does not end at sentence boundary: '#{chunk[:content]}'")
    end
  end

  test "never splits mid-sentence" do
    text = "First sentence here. Second sentence follows. Third sentence appears. Fourth sentence now. Fifth one too."
    all_sentences = PragmaticSegmenter::Segmenter.new(text: text).segment.map(&:strip)
    result = Preprocessing::Chunker.call(text, chunk_size: 50, overlap: 0)

    result.each do |chunk|
      # Each sentence that starts in the chunk must be fully contained
      all_sentences.each do |sentence|
        if chunk[:content].start_with?(sentence[0..5])
          assert_includes chunk[:content], sentence,
            "Chunk contains partial sentence: '#{chunk[:content]}'"
        end
      end
    end
  end

  test "single long sentence exceeding chunk_size stays intact" do
    text = "This is a very long sentence that exceeds the chunk size limit but should still be kept whole because we never split mid-sentence."
    result = Preprocessing::Chunker.call(text, chunk_size: 50, overlap: 0)
    assert_equal 1, result.length
    assert_equal text, result.first[:content]
  end

  test "overlap repeats trailing sentences from previous chunk" do
    text = "Alpha. Bravo. Charlie. Delta. Echo. Foxtrot."
    result = Preprocessing::Chunker.call(text, chunk_size: 25, overlap: 1)

    if result.length > 1
      result.each_cons(2) do |prev_chunk, next_chunk|
        prev_last_sentence = prev_chunk[:content].split(". ").last.delete_suffix(".")
        assert_includes next_chunk[:content], prev_last_sentence,
          "Expected overlap: '#{prev_last_sentence}' should appear in next chunk"
      end
    end
  end

  test "covers entire text from start to end" do
    text = "The quick brown fox. Jumps over the lazy dog. Many more words here."
    result = Preprocessing::Chunker.call(text)
    assert_equal 0, result.first[:start_char]
    assert_equal text.strip.length, result.last[:end_char]
  end

  test "class-level call delegates to instance" do
    text = "Hello world. Goodbye world."
    assert_equal Preprocessing::Chunker.new(text).call,
                 Preprocessing::Chunker.call(text)
  end

  test "start_char and end_char map back to original text" do
    text = "First sentence. Second sentence. Third sentence."
    result = Preprocessing::Chunker.call(text, chunk_size: 30, overlap: 0)

    result.each do |chunk|
      original_slice = text[chunk[:start_char]...chunk[:end_char]]
      assert original_slice.present?,
        "Slice from #{chunk[:start_char]}...#{chunk[:end_char]} is empty"
    end
  end
end
