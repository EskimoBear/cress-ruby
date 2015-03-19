require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/language'
require_relative '../lib/eson/token_pass'

describe Eson::Language::RuleSeq::Rule do

  subject {Eson::Language::RuleSeq::Rule}
  let(:token) {Eson::Language::LexemeCapture::Token}
  let(:token_seq) {Eson::TokenPass::TokenSeq}
  let(:rule_seq) {Eson::Language::RuleSeq.new([subject.new(:rule_1, /RU/),
                                               subject.new(:rule_2, /LE/),
                                               subject.new(:rule_3, /RL/)])}
  
  describe "#parse" do
    describe "terminal_rule" do
      before do
        @rule = subject.new_terminal_rule(:token_name, /RULE/)
        @valid_token = token.new(:lexeme, :token_name)
        @valid_token_seq = token_seq.new([@valid_token])
        @invalid_token = token.new(:lexeme, :invalid_token_name)
        @invalid_token_seq = @valid_token_seq.clone.unshift(@invalid_token)
      end
      it "with valid token" do
        seq = @rule.parse(@valid_token_seq, rule_seq)
        seq.must_be_instance_of Hash
        seq[:parsed_seq].must_be_instance_of token_seq
        seq[:parsed_seq].detect{|i| i.name == :token_name}.wont_be_nil true
        seq[:rest].must_be_instance_of token_seq
      end
      it "with invalid token" do
        proc {@rule.parse(@invalid_token_seq, rule_seq)}
          .must_raise Eson::Language::RuleSeq::Rule::ParseError
      end
    end
    describe "alternation_rule" do
      before do
        @rules = rule_seq.make_alternation_rule(:terminal_rule, [:rule_2, :rule_1])
        @rule = @rules.get_rule(:terminal_rule)
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_3)]
        @valid_token_seq = token_seq.new(@sequence)
        @invalid_token_seq = @valid_token_seq.reverse
      end
      describe "only terminals" do 
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @valid_token_seq.first(1)
          seq[:rest].must_equal @valid_token_seq.last(1)
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
      describe "with nonterminals" do
        before do
          @rules = @rules.make_alternation_rule(:nonterminal_rule, [:terminal_rule, :rule_3])
          @rule = @rules.get_rule(:nonterminal_rule)
          @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_4)]
          @valid_token_seq = token_seq.new @sequence
          @invalid_token_seq = @valid_token_seq.reverse
        end
        it "with valid token" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @valid_token_seq.first(1)
          seq[:rest].must_equal @valid_token_seq.last(1)
        end
        it "with invalid token" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
    end
    describe "concatenation rule" do
      before do
        @rules = rule_seq.make_concatenation_rule(:terminal_rule, [:rule_1, :rule_2])
        @rule = @rules.get_rule(:terminal_rule)
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
        @valid_token_seq = token_seq.new(@sequence)
        @invalid_token_seq = @valid_token_seq.reverse
      end
      describe "with only terminals" do
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @sequence
          seq[:rest].must_be_empty
        end
        it "with invalid token" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
      describe "with nonterminals" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:nonterminal_rule, [:terminal_rule, :rule_3])
          @rule = @rules.get_rule(:nonterminal_rule)
          @sequence = @sequence.push(token.new(:lexeme, :rule_3))
          @valid_token_seq = token_seq.new(@sequence)
          @invalid_token_seq = @valid_token_seq.take(2).push(token.new(:lexeme, :rule_1))
        end
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @sequence
          seq[:rest].must_be_empty
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
    end
    describe "repetition rule" do
      before do
        @rules = rule_seq
                 .make_repetition_rule(:terminal_rule, :rule_1)
        @lang = @rules.build_language("LANG")
        @rule = @lang.terminal_rule
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_1)]
        @valid_token_seq = token_seq.new(@sequence)
        @follow_sequence = [token.new(:lexeme, :rule_3), token.new(:lexeme, :rule_1)]
        @invalid_sequence = [token.new(:lexeme, :rule_2), token.new(:lexeme, :rule_1)]
        @invalid_token_seq = token_seq.new(@invalid_sequence)
      end
      describe "with terminals only" do
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @valid_token_seq
          seq[:rest].must_be_empty
        end
        it "with invalid terminal" do
          proc{@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
      describe "with nonterminals" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:c_rule, [:rule_1, :rule_2])
                   .make_repetition_rule(:non_terminal_rule, :c_rule)
                   .make_concatenation_rule(:top, [:non_terminal_rule, :rule_3])
          @lang = @rules.build_language("LANG", :top)
          @sequence  = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
          @valid_once_seq = token_seq.new(@sequence).concat(@invalid_sequence)
          @valid_many_seq = token_seq.new(@sequence)
                             .concat(@sequence)
                             .concat(@invalid_sequence)
          @valid_nulled_seq = token_seq.new(@follow_sequence)
          @rule = @lang.non_terminal_rule
        end
        it "appears once" do
          seq = @rule.parse(@valid_once_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @valid_once_seq.take(2)
        end
        it "appears many times" do
          seq = @rule.parse(@valid_many_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @valid_many_seq.take(4)
          seq[:rest].must_equal @invalid_sequence
        end
        it "nulled instance" do
          seq = @rule.parse(@valid_nulled_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_be_empty
          seq[:rest].must_equal @valid_nulled_seq
        end
        it "with invalid tokens" do
          proc{@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
    end
    describe "option rule" do
      before do
        @rules = rule_seq
                 .make_option_rule(:terminal_rule, :rule_1)
        @lang = @rules.build_language("LANG")
        @rule = @lang.terminal_rule
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
        @valid_token_seq = token_seq.new(@sequence)
        @nulled_sequence = [token.new(:lexeme, :rule_3), token.new(:lexeme, :rule_1)]
        @valid_nulled_seq = token_seq.new(@nulled_sequence)
        @invalid_token_seq = @valid_token_seq.reverse
      end
      describe "with terminals only" do
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @sequence.first(1)
          seq[:rest].must_equal @sequence.last(1)
        end
      end
      describe "with nonterminal" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:c_rule, [:rule_1, :rule_2])
                   .make_option_rule(:non_terminal_rule, :c_rule)
                   .make_concatenation_rule(:top, [:non_terminal_rule, :rule_3])
          @lang = @rules.build_language("LANG", :top)
          @rule = @lang.non_terminal_rule
        end
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].must_equal @sequence
          seq[:rest].must_be_empty
        end
        it "nulled instance" do
          seq = @rule.parse(@valid_nulled_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_empty
          seq[:rest].must_equal @valid_nulled_seq
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
    end
  end
end
