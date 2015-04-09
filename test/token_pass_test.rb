require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe Eson::TokenPass do
  subject {Eson::TokenPass}

  describe "with_full_eson_program" do
    before do
      @program = TestHelpers.get_tokenizer_sample_program
      @token_sequence, @input_sequence = subject.tokenize_program(@program)
    end    
    it "has empty input sequence" do
      @input_sequence.empty?.must_equal true 
    end
    it "has filled token sequence" do
      @token_sequence.empty?.wont_equal true 
    end
    it "has only tokens in sequence" do
      token_seq_length = @token_sequence.length
      valid_token_seq_length = @token_sequence.select{|i| i.class == Eson::Language::LexemeCapture::Token}.length
      (token_seq_length == valid_token_seq_length).must_equal true
    end
    it "is a TokenSeq" do
      assert @token_sequence.instance_of? Eson::TokenPass::TokenSeq
    end
  end
  
  describe "empty_eson_program" do
    before do
      @empty_program = TestHelpers.get_empty_program
      @token_sequence, @input_sequence = subject.tokenize_program(@empty_program)
    end
    it "has empty input sequence" do
      @input_sequence.empty?.must_equal true
    end
    it "has full token sequence" do
      @token_sequence.empty?.wont_equal true
    end
    it "has only tokens in sequence" do
      token_seq_length = @token_sequence.length 
      valid_token_seq_length = @token_sequence.select{|i| i.class == Eson::Language::LexemeCapture::Token}.length
      (token_seq_length == valid_token_seq_length).must_equal true
    end
  end
end
