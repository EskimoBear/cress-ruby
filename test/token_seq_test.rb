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

  def test_consecutive_ints_should_succeed
    assert @token_seq.consecutive_ints?(@consecutive_int_array)
  end

  def test_consecutive_ints_should_fail
    refute @token_seq.consecutive_ints?(@invalid_int_array)
  end

  def test_consecutive_ints_should_fail_with_empty_array
    refute @token_seq.consecutive_ints?([])
  end

  def test_take_while_seq_should_succeed
    @token_seq[3].name = "target_1"
    @token_seq.last.name = "target_2"
    @token_seq.push(Eson::Tokenizer::Token["lexeme", "name"])
    expected_seq =  @token_seq.take(@token_seq.length - 1)
    assert_equal expected_seq, @token_seq.take_while_seq("target_1", "target_2")
  end

  def test_take_while_seq_should_fail
    assert_nil @token_seq.take_while_seq("target_1", "target_2")
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

  def test_tokenize_variable_identifiers_should_succeed
    @token_seq[3].name = :variable_prefix
    @token_seq[3].lexeme = :"$"
    @token_seq.last.name = :word
    @token_seq.last.lexeme = :variable
    @token_seq.push(Eson::Tokenizer::Token[:lexeme, :name])
    result = @token_seq.tokenize_variable_identifiers
    refute_nil result.detect {|i| i.name == :variable_identifier}
    assert result.instance_of? Eson::Tokenizer::TokenSeq
  end
  
end

describe Eson::Tokenizer::TokenSeq do

  it "#swap_tail" do
    
  end

end
