require 'minitest/autorun'
require 'minitest/pride'
require 'oj'
require_relative './test_helpers.rb'
require_relative '../lib/eson/tokenizer.rb'

describe Eson::Tokenizer do

  describe "with valid JSON string input" do
    before do
      @program = TestHelpers.get_tokenizer_eson
      @final_token_sequence, @final_input_sequence = Eson::Tokenizer.tokenize_program(@program)
    end

    describe "final state" do
      it "has empty input sequence" do
        @final_input_sequence.empty?.must_equal true 
      end
      it "has filled token sequence" do
        @final_token_sequence.empty?.wont_equal true 
      end
      it "has only tokens in sequence" do
        token_seq_length = @final_token_sequence.length 
        valid_token_seq_length = @final_token_sequence.select{|i| i.class == Struct::Token}.length
        (token_seq_length == valid_token_seq_length).must_equal true
      end
    end
  end

end

class TokenizerTest < MiniTest::Unit::TestCase

  include TestHelpers

end
