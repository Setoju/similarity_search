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
    result = Preprocessing::Chunker.call("Hello world")
    assert_equal 1, result.length
    assert_equal "Hello world", result.first[:content]
    assert_equal 0, result.first[:start_char]
    assert_equal 11, result.first[:end_char]
  end

  test "chunks include expected keys" do
    result = Preprocessing::Chunker.call("Hello world")
    chunk = result.first
    assert chunk.key?(:content)
    assert chunk.key?(:start_char)
    assert chunk.key?(:end_char)
  end

  test "chunk content always matches the text slice" do
    text = "The quick brown fox jumps over the lazy dog."
    result = Preprocessing::Chunker.call(text)
    result.each do |chunk|
      assert_equal text[chunk[:start_char]...chunk[:end_char]], chunk[:content]
    end
  end

  test "splits long text into multiple chunks" do
    text = "word " * 200  # 1000 chars
    result = Preprocessing::Chunker.call(text)
    assert result.length > 1
  end

  test "respects custom chunk_size" do
    text = "a" * 200
    result = Preprocessing::Chunker.call(text, chunk_size: 50, overlap: 0)
    result.each do |chunk|
      assert chunk[:content].length <= 50
    end
  end

  test "overlapping chunks produce overlapping char ranges" do
    text = "word " * 50  # 250 chars
    result = Preprocessing::Chunker.call(text, chunk_size: 100, overlap: 20)

    if result.length > 1
      first_end    = result[0][:end_char]
      second_start = result[1][:start_char]
      assert second_start < first_end, "Expected overlap but second chunk starts after first ends"
    end
  end

  test "covers entire text without skipping characters" do
    text = "The quick brown fox. " * 10
    result = Preprocessing::Chunker.call(text)

    assert_equal 0, result.first[:start_char]
    result.each_cons(2) do |prev, curr|
      assert curr[:start_char] < prev[:end_char], "Gap detected between consecutive chunks"
    end
  end

  test "class-level call delegates to instance" do
    text = "Hello world"
    assert_equal Preprocessing::Chunker.new(text).call,
                 Preprocessing::Chunker.call(text)
  end

  test "breaks at word boundaries when possible" do
    text = "hello world foo bar baz qux " * 20  # lots of words
    result = Preprocessing::Chunker.call(text, chunk_size: 30, overlap: 0)
    # No chunk should end mid-word (no chunk content should end with a non-space char
    # that is followed by a non-space in the original text)
    result.each do |chunk|
      end_idx = chunk[:end_char]
      # If not at end of string, the char right at end_idx should not be mid-word
      next if end_idx >= text.length

      assert text[end_idx - 1] == " " || text[end_idx] == " ",
             "Chunk ending at #{end_idx} appears to split a word: '...#{text[end_idx - 3, 6]}...'"
    end
  end
end
