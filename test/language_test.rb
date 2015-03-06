require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/language.rb'
require_relative '../lib/eson/tokenizer'

describe Eson::Language::RuleSeq do

  subject {Eson::Language::RuleSeq}
  let(:rule) {Eson::Language::RuleSeq::Rule}
  let(:rule_seq) {subject.new([rule.new(:rule_1, /RU/),
                               rule.new(:rule_2, /LE/)])}
  
  describe ".new" do
    it "item is a Rule" do
      proc {subject.new([rule.new(nil, nil)])}.must_be_silent
    end
    it "items not a Rule" do
      proc {subject.new([45])}.must_raise Eson::Language::RuleSeq::ItemError
    end
  end

  describe "#convert_to_terminal" do
    before do
      @rules = rule_seq
               .make_concatenation_rule(:rule_3, [:rule_1, :rule_2])
               .convert_to_terminal(:rule_3)
      @new_rule = @rules.get_rule(:rule_3)
      @first_set = @new_rule.first_set
    end
    it "has correct properties" do
      @rules.must_be_instance_of subject
      @new_rule.terminal?.must_equal true
      @new_rule.ebnf.must_be_nil
      @first_set.must_include @new_rule.name
      @new_rule.nullable?.must_equal false
    end
    it "is partial rule" do
      @rules.make_concatenation_rule(:rule_4, [:rule_2, :undefined])
      proc {@rules.convert_to_terminal(:rule_4)}.must_raise Eson::Language::RuleSeq::ConversionError
    end
  end

  describe "#remove_rules" do
    it "succeeds" do
      rules = rule_seq.remove_rules([:rule_1])
      rules.must_be_instance_of subject
      proc {rules.get_rule(:rule_1)}.must_raise Eson::Language::RuleSeq::ItemError
      rules.length.must_equal 1
    end
    it "fails" do
      rule_seq.remove_rules([:not_there]).must_be_nil
    end
  end

  describe "#build_language" do
    before do
      @rules = rule_seq.
               make_concatenation_rule(:rule_3, [:rule_1, :rule_2])
    end
    it "has correct properties" do
      @rules.build_language("LANG").must_be_instance_of Struct::LANG
    end
    it "has no partial first sets" do
      @rules.build_language("LANG").rule_3.partial_status.must_equal false
    end
  end

  describe "to_s" do
    it "success" do
      rule_seq.build_language("LANG").to_s.must_match /has the following production rules/
    end
  end

  describe "#make_terminal_rule" do
    it "has correct properties" do
      @rule = subject::Rule.new_terminal_rule(:rule, /k/)
      @rule.must_be_instance_of rule
      @rule.terminal?.must_equal true
      @rule.ebnf.must_be_nil true
    end
  end
  
  describe "#make_alternation_rule" do
    it "has correct properties" do
      @rules = rule_seq.make_alternation_rule(:new_rule, [:rule_1, :rule_2])
      @new_rule = @rules.get_rule(:new_rule)
      @rules.must_be_instance_of subject
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.ebnf.must_be_instance_of Eson::Language::EBNF::AlternationRule
      @new_rule.nullable?.must_equal false
      @new_rule.first_set.must_include :rule_1
      @new_rule.first_set.must_include :rule_2
      @new_rule.partial_status.must_equal false
    end
    describe "with undefined rules" do
      before do
        @rules = rule_seq.make_alternation_rule(:new_rule, [:rule_2, :undefined])
        @new_rule = @rules.get_rule(:new_rule)
        @term_names = @new_rule.ebnf.term_set.map{|i| i.rule_name}
      end
      it "is partial" do
        @new_rule.partial_status.must_equal true
      end
      it "contains all terms" do
        @term_names.must_include :rule_2
        @term_names.must_include :undefined
      end
      it "has partial first set" do
        @new_rule.partial_status.must_equal true
        @new_rule.first_set.must_be_empty
      end
    end
  end

  describe "#make_concatenation_rule" do
    it "succeeds" do
      @rules = rule_seq.make_concatenation_rule(:new_rule, [:rule_1, :rule_2])
      @new_rule = @rules.get_rule(:new_rule)
      @rules.must_be_instance_of subject
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.ebnf.must_be_instance_of Eson::Language::EBNF::ConcatenationRule
      @new_rule.nullable?.must_equal false
      @new_rule.first_set.must_include :rule_1
      @new_rule.partial_status.must_equal false
    end
    describe "starts with undefined term" do
      before do
        @rules = rule_seq.make_concatenation_rule(:new_rule, [:undefined, :rule_1])
        @new_rule = @rules.get_rule(:new_rule)
      end
      it "has correct properties" do
        @rules.must_be_instance_of subject
        @new_rule.must_be_instance_of rule
        @new_rule.nonterminal?.must_equal true
      end
      it "has partial status" do
        @new_rule.partial_status.must_equal true
      end
      it "empty first set" do
        @new_rule.first_set.must_be_empty
      end
    end
    describe "with illegal left recursion" do
    end
  end

  describe "#make_repetition_rule" do
    it "has correct properties" do
      @rules = rule_seq.make_repetition_rule(:new_rule, :rule_1)
      @new_rule = @rules.get_rule(:new_rule)     
      @rules.must_be_instance_of subject
      @new_rule.ebnf.must_be_instance_of Eson::Language::EBNF::RepetitionRule
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.nullable?.must_equal true
      @new_rule.first_set.must_include :rule_1
      @new_rule.first_set.must_include :nullable
    end
    describe "has undefined term" do
      before do
        @rules = rule_seq.make_repetition_rule(:new_rule, :undefined)
        @new_rule = @rules.get_rule(:new_rule)
      end
      it "has correct properties" do
        @rules.must_be_instance_of subject
        @new_rule.must_be_instance_of rule
        @new_rule.nonterminal?.must_equal true
      end
      it "inherits partial first set" do
        @new_rule.partial_status.must_equal true
        @new_rule.first_set.must_include :nullable
      end
    end
  end

  describe "#make_option_rule" do
    it "has correct properties" do
      @rules = rule_seq.make_option_rule(:new_rule, :rule_1)
      @new_rule = @rules.get_rule(:new_rule)
      @rules.must_be_instance_of subject
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.ebnf.must_be_instance_of Eson::Language::EBNF::OptionRule
      @new_rule.nullable?.must_equal true
      @new_rule.first_set.must_include :rule_1
      @new_rule.first_set.must_include :nullable
    end
    describe "has undefined term" do
      before do
        @rules = rule_seq.make_option_rule(:new_rule, :undefined)
        @new_rule = @rules.get_rule(:new_rule)
      end
      it "has correct properties" do
        @rules.must_be_instance_of subject
        @new_rule.must_be_instance_of rule
        @new_rule.nonterminal?.must_equal true
      end
      it "inherits partial first set" do
        @new_rule.partial_status.must_equal true
        @new_rule.first_set.must_include :nullable
      end
    end
  end
end

describe Eson::Language::RuleSeq::Rule do

  subject {Eson::Language::RuleSeq::Rule}
  let(:token) {Eson::Tokenizer::TokenSeq::Token}
  let(:token_seq) {Eson::Tokenizer::TokenSeq}
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
          seq[:parsed_seq].length.must_equal 1
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
          seq[:parsed_seq].length.must_equal 1
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
          seq[:parsed_seq].length.must_equal 2
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
          seq[:parsed_seq].length.must_equal 3
          seq[:parsed_seq].must_equal @sequence
          seq[:rest].must_be_empty
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Language::RuleSeq::Rule::ParseError
        end
      end
    end
    describe "option rule" do
      before do
        @rules = rule_seq.make_option_rule(:terminal_rule, :rule_1)
        @rule = @rules.get_rule(:terminal_rule)
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
        @valid_token_seq = token_seq.new(@sequence)
        @invalid_token_seq = @valid_token_seq.reverse
      end
      describe "with terminals only" do
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].length.must_equal 1
          seq[:parsed_seq].must_equal @sequence.first(1)
          seq[:rest].must_equal @sequence.last(1)
        end
      end
      describe "with nonterminal" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:c_rule, [:rule_1, :rule_2])
                   .make_option_rule(:nonterminal_rule, :c_rule)
          @rule = @rules.get_rule(:nonterminal_rule)
        end
        it "with valid tokens" do
          seq = @rule.parse(@valid_token_seq, @rules)
          seq.must_be_instance_of Hash
          seq[:parsed_seq].must_be_instance_of token_seq
          seq[:parsed_seq].length.must_equal 2
          seq[:parsed_seq].must_equal @sequence
          seq[:rest].must_be_empty
        end
      end
    end
  end
end
