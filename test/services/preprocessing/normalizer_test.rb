require "test_helper"

class Preprocessing::NormalizerTest < ActiveSupport::TestCase
  test "converts text to lowercase" do
    assert_equal "hello world", Preprocessing::Normalizer.call("HELLO WORLD")
    assert_equal "mixed case", Preprocessing::Normalizer.call("MiXeD CaSe")
  end

  test "strips leading and trailing whitespace" do
    assert_equal "hello", Preprocessing::Normalizer.call("  hello  ")
    assert_equal "hello", Preprocessing::Normalizer.call("\thello\n")
  end

  test "collapses multiple spaces into one" do
    assert_equal "hello world", Preprocessing::Normalizer.call("hello    world")
    assert_equal "a b c", Preprocessing::Normalizer.call("a   b   c")
  end

  test "handles mixed whitespace" do
    assert_equal "hello world", Preprocessing::Normalizer.call("  HELLO   WORLD  ")
    assert_equal "test input", Preprocessing::Normalizer.call("\n\tTEST\n\tINPUT\t\n")
  end

  test "handles empty string" do
    assert_equal "", Preprocessing::Normalizer.call("")
  end
end
