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

  describe "program_with_unknown_special_forms" do
    it ".compile" do
      proc {Eson.compile(@unknown_special_form_program)}
        .must_raise Eson::TokenPass::TokenSeq::SpecialFormError
    end
  end

  describe "compile_valid_program" do
    before do
      @token_sequence = get_token_sequence
    end 
    it "#add_line_numbers" do
      @token_sequence.last.line_number.must_equal 6
      @token_sequence.find_all {|i| i.line_number == nil}.size.must_equal 0
    end
    it "#tokenize_variable_identifier" do
      @token_sequence.must_be_instance_of Eson::TokenPass::TokenSeq
      @token_sequence.find_all {|i| i.name == :variable_identifier}.length.must_equal 1
    end
    it "tokenize_proc_identifier" do
      @token_sequence.find_all {|i| i.name == :proc_identifier}.length.must_equal 4
    end
    it "#tokenize_word_form" do
      @token_sequence.must_be_instance_of Eson::TokenPass::TokenSeq
      @token_sequence.find_all {|i| i.name == :word_form}.length.must_equal 7
    end
    it "#label_sub_strings" do
      @token_sequence.must_be_instance_of Eson::TokenPass::TokenSeq
      @token_sequence.find_all {|i| i.alternation_names.to_a.include?(:sub_string)}.length.must_equal 8
    end
    it "#insert_string_delimiters" do
      @token_sequence.must_be_instance_of Eson::TokenPass::TokenSeq
      @token_sequence.find_all {|i| i.name == :string_delimiter}.length.must_equal 12
    end
    it "build_tree" do
      #@tree.must_be_instance_of Eson::Language::AST
    end
  end
end


