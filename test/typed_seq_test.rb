require 'minitest/autorun'
require 'minitest/pride'
require_relative '../utils/typed_seq'

describe TypedSeq, "Demo" do

  subject {TypedSeq}

  before do
    @string_seq = TypedSeq.new_seq(String)
    @bad_param = ["wrong", 9]
  end

  describe "#initialize" do
    it "with no params" do
      StringSeq = @string_seq
      @string_seq.new.class.must_equal StringSeq
    end
    it "with incorrect type" do
      proc {@string_seq.new(@bad_param)}
        .must_raise TypedSeq::WrongInitializationType
    end
  end
  describe "#push" do
    it "with incorrect type" do
      proc {@string_seq.new.push(@bad_param)}
        .must_raise TypedSeq::WrongElementType
    end
    it "with correct type" do
      test_seq = @string_seq.new
      size = test_seq.length
      test_seq.push("right")
      test_seq.length.must_equal size + 1
    end
  end
end
