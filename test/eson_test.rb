require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'
require_relative './test_helpers.rb'

describe Eson do

  include TestHelpers
  
  before do
    @empty_program = get_empty_program
    @unknown_special_form_program = get_unknown_special_form_program
    @invalid_program = get_invalid_program
    @valid_program = get_tokenizer_sample_program
  end

  describe "empty program" do
    it ".compile" do
      Eson.compile(@empty_program).must_be_nil
    end
  end

  describe "invalid program" do
    it ".compile" do
      proc {Eson.compile(@invalid_program)}.must_raise Eson::SyntaxError
    end
  end

  describe "program with unknown special forms" do
    it ".compile" do
      proc {Eson.compile(@unknown_special_form_program)}.must_raise Eson::ErrorPass::SpecialFormError
    end
  end

  describe "compile valid_program" do
    before do
      @result = Eson.compile(@valid_program)
    end
    
    it "#add_line_numbers" do
      @result.last.line_number.must_equal 6
      @result.find_all {|i| i.line_number == nil}.size.must_equal 0
    end
    it "#tokenize_variable_identifier" do
      @result.must_be_instance_of Eson::Tokenizer::TokenSeq
      @result.find_all {|i| i.name == :variable_identifier}.length.must_equal 1
    end
    it "#tokenize_word_form" do
      @result.must_be_instance_of Eson::Tokenizer::TokenSeq
      @result.find_all {|i| i.name == :word_form}.length.must_equal 6
    end
    it "#label_sub_strings" do
      @result.must_be_instance_of Eson::Tokenizer::TokenSeq
      @result.find_all {|i| i.alternation_names.to_a.include?(:sub_string)}.length.must_equal 7
    end
    it "#insert_string_delimiters" do
      @result.must_be_instance_of Eson::Tokenizer::TokenSeq
      @result.find_all {|i| i.name == :string_delimiter}.length.must_equal 10
    end
  end
end


