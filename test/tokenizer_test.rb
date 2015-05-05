require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'
require_relative '../lib/eson/tokenizer.rb'

describe Eson::TokenPass::Tokenizer do

  include TestHelpers

  before do
    @token_sequence = get_token_sequence
  end
  it "is a TokenSeq" do
    @token_sequence.must_be_instance_of Eson::TokenPass::TokenSeq
  end
  it "#add_line_numbers" do
    @token_sequence.last.line_number.must_equal 6
    @token_sequence.find_all {|i| i.line_number == nil}.size.must_equal 0
  end
  it "#tokenize_variable_identifier" do
    @token_sequence.find_all {|i| i.name == :variable_identifier}.length.must_equal 1
  end
  it "tokenize_proc_identifier" do
    @token_sequence.find_all {|i| i.name == :special_form_identifier}.length.must_equal 4
  end
  it "#tokenize_word_form" do
    @token_sequence.find_all {|i| i.name == :word_form}.length.must_equal 26
  end
  it "#label_sub_strings" do
    @token_sequence.find_all {|i| i.alternation_names.to_a.include?(:sub_string)}
      .length.must_equal 27
  end
  it "#insert_string_delimiters" do
    @token_sequence.find_all {|i| i.name == :string_delimiter}.length.must_equal 12
  end
end
