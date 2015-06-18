require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative './test_helpers.rb'
require_relative '../lib/dote/tokenizer.rb'

describe Dote::TokenPass::Tokenizer do

  include TestHelpers

  before do
    @token_sequence = get_token_sequence
  end
  it "is a TokenSeq" do
    @token_sequence.must_be_instance_of Dote::TokenPass::TokenSeq
  end
  it "eval :line_no" do
    @token_sequence.last.get_attribute(:line_no).must_equal 17
    @token_sequence.all?{|i| i.get_attribute(:line_no)}
      .must_equal true
  end
  it "eval :indent" do
    @token_sequence.map{|i| i.get_attribute(:indent)}.max
      .must_equal 3
    @token_sequence.all?{|i| i.get_attribute(:indent)}
      .must_equal true
  end
  it "eval :spaces_after" do
    @token_sequence.select{|i| i.get_attribute(:spaces_after)}
      .length.must_equal 8
  end
end
