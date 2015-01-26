require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/tokenizer.rb'
require_relative './test_helpers.rb'

class TestTokenSeq < MiniTest::Test

  def setup
    @token_seq = Eson::Tokenizer::TokenSeq.new(5) {Eson::Tokenizer::Token.new}
    @consecutive_int_array = [4, 5, 6]
    @invalid_int_array = [3, 1, 9]
  end

  def test_swap_tail_should_succeed
    new_tail = Eson::Tokenizer::Token["lexeme", "name"]
    @token_seq.swap_tail(3, new_tail)
    assert_equal @token_seq.last, new_tail, "last item in token seq should be the new tail"
    assert @token_seq.length == 3, "token seq should be length 3"
  end

  def test_take_with_seq_should_succeed
    @token_seq[3].name = "target_1"
    @token_seq.last.name = "target_2"
    @token_seq.push(Eson::Tokenizer::Token["lexeme", "name"])
    expected_seq =  @token_seq.take(@token_seq.length - 1)
    assert_equal expected_seq, @token_seq.take_with_seq("target_1", "target_2")
  end

  def test_take_with_seq_should_fail
    assert_nil @token_seq.take_with_seq("target_1", "target_2")
  end

  def test_seq_match_should_succeed 
    @token_seq[1].name = "target_2"
    @token_seq[3].name = "target_1"
    @token_seq.last.name = "target_2"
    @token_seq.push(Eson::Tokenizer::Token["lexeme", "target_2"])
    assert @token_seq.seq_match?("target_1", "target_2")
  end

  def test_seq_match_should_fail 
    @token_seq[2].name = "target_1"
    @token_seq.last.name = "target_2"
    refute @token_seq.seq_match?("target_1", "target_2")
  end
 
end

describe Eson::Tokenizer::TokenSeq do

  before do
    @alternation_rule = Eson::Language.e1.word_form
    @concatenation_rule = Eson::Language.e0.variable_identifier
    @token_seq = Eson::Tokenizer::TokenSeq.new(4) {Eson::Tokenizer::Token.new}
  end
  
  describe "#tokenize_rule" do
    it "with alternation rule" do
      @token_seq[0].name = :variable_prefix
      @token_seq[1].name = :whitespace
      @token_seq[2].name = :other_chars
      @token_seq[3].name = :word
      @token_seq.tokenize_rule(@alternation_rule)
      @token_seq.all?{|i| i.name == @alternation_rule.name}.must_equal true
    end
    it "with concatenation rule" do
      @token_seq[0].name = :variable_prefix
      @token_seq[0].lexeme = :word_1
      @token_seq[1].name = :word
      @token_seq[1].lexeme = :word_2
      @token_seq[2].name = :variable_prefix
      @token_seq[2].lexeme = :word_1
      @token_seq[3].name = :word
      @token_seq[3].lexeme = :word_2
      @token_seq.all?{|i| i.name == @concatenation_rule.name}
      @token_seq.must_be_instance_of Eson::Tokenizer::TokenSeq
    end
  end
end
