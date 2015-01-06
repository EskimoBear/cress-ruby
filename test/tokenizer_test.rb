require 'minitest/autorun'
require 'minitest/pride'
require 'oj'
require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe Eson::Tokenizer do

  describe "with valid JSON string input" do
    before do
      @program = TestHelpers.get_tokenizer_eson
      @program_input = Oj.dump(Oj.load(@program))
      @final_token_sequence, @final_input_sequence = Eson::Tokenizer.tokenize_program(@program_input)
    end

    describe "final state" do
      it "has empty input sequence" do
        skip
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
      it "sequences has same char length" do
        skip
        token_seq_char_length = @final_token_sequence.inject(0)do |sum, i|
          if i.name == :array || :number
            puts "#{i.name} - '#{i.value}' - #{i.value.to_s.size}"
            i.value.to_s.size + sum
          else
            puts "#{i.name} - '#{i.value}'- #{i.value.size}"
            i.value.size + sum
          end
        end
        @program_input.length.must_equal token_seq_char_length
      end
    end
  end

end

class TokenizerTest < MiniTest::Unit::TestCase

  include TestHelpers

end
