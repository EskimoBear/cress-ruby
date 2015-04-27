require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/typed_seq'

describe TypedSeq, "Demo" do

  subject {TypedSeq}

  before do
    @string_seq = TypedSeq.new_seq(String)
    @bad_param = ["wrong", 9]
  end

  describe "#initialize" do
    it "with no params" do
      @string_seq.new
      @string_seq.must_respond_to :enforce_type
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
  end
end
