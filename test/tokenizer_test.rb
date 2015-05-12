require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
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
    @token_sequence.print_program
    @token_sequence.last.get_attribute(:line_no).must_equal 17
    @token_sequence.all?{|i| i.get_attribute(:line_no)}
      .must_equal true
  end
  it "#insert_string_delimiters" do
    @token_sequence.find_all{|i| i.name == :string_delimiter}.length.must_equal 12
  end
end
