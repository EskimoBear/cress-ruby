require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/token_pass'

describe Eson::Language::RuleSeq do

  subject {Eson::Language::RuleSeq}
  let(:rule) {Eson::Language::RuleSeq::Rule}
  let(:rule_seq) {subject.new([rule.new(:rule_1, /RU/),
                               rule.new(:rule_2, /LE/)])}
  
  describe ".new" do
    it "item is a Rule" do
      proc {subject.new([rule.new(nil, nil)])}.must_be_silent
    end
    it "item is not a Rule" do
      proc {subject.new([45])}.must_raise Eson::Language::RuleSeq::WrongElementType
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
      proc {@rules.convert_to_terminal(:rule_4)}.must_raise Eson::Language::RuleSeq::CannotMakeTerminal
    end
  end

  describe "#remove_rules" do
    it "succeeds" do
      rules = rule_seq.remove_rules([:rule_1])
      rules.must_be_instance_of subject
      proc {rules.get_rule(:rule_1)}.must_raise Eson::Language::RuleSeq::MissingRule
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
      it "inherits nullable state" do
        rules = rule_seq.make_option_rule(:o_rule, :rule_1)
                .make_alternation_rule(:rule, [:rule_2, :o_rule])
        rules.get_rule(:rule).nullable?.must_equal true
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
    describe "start with nullable terms" do
      before do
        @rules = rule_seq.make_option_rule(:o_rule_1, :rule_1)
                 .make_option_rule(:o_rule_2, :rule_2)
                 .make_concatenation_rule(:rule, [:o_rule_1, :o_rule_2, :rule_2])
        @rule = @rules.get_rule(:rule)
      end
      it "has correct first set" do
        lang = @rules.build_language("LANG")
        rule = lang.rule
        rule.first_set.must_include :rule_1
        rule.first_set.must_include :rule_2
      end
      it "no duplicates in first set" do
        lang = @rules.build_language("LANG")
        lang.rule.first_set.uniq!.must_be_nil
      end
    end
    describe "with only nullable terms" do
      before do
        @rules = rule_seq.make_option_rule(:o_rule_1, :rule_1)
                 .make_option_rule(:o_rule_2, :rule_2)
                 .make_concatenation_rule(:rule, [:o_rule_1, :o_rule_2])
        @rule = @rules.get_rule(:rule)
      end
      it "inherit nullable status" do
        @rule.nullable?.must_equal true
      end
      it "has correct first set" do
        lang = @rules.build_language("LANG")
        rule = lang.rule
        rule.first_set.must_include :rule_1
        rule.first_set.must_include :rule_2
        rule.first_set.must_include :nullable
      end
    end
    describe "follow sets" do
      before do
        @rules = rule_seq.make_option_rule(:o_rule_1, :rule_1)
                 .make_concatenation_rule(:rule, [:rule_2, :o_rule_1])
        @lang = @rules.build_language("LANG", :rule)
      end
      it ":top_rule correct" do
        @lang.top_rule.follow_set.must_include :eof
        @lang.top_rule.follow_set.length.must_equal 1
      end
      it ":o_rule_1 correct" do
        @lang.o_rule_1.follow_set.must_include :eof
      end
      it ":rule_1 correct" do
        @lang.rule_1.follow_set.must_include :eof
      end
      it ":rule_2 correct" do
        @lang.rule_2.follow_set.must_include :rule_1
        @lang.rule_2.follow_set.wont_include :nullable
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
