require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/language.rb'

describe Eson::Language do
  
  describe "validate e0 properties" do
    it "should be E0" do
      Eson::Language.e0.class.must_equal Struct::E0
    end
    it "should be aliased" do
      Eson::Language.must_respond_to :tokenizer_lang
    end
    it "should contain built rules" do
      Eson::Language.e0.values.detect{|i| i.name == :special_form}.wont_be_nil
      Eson::Language.e0.values.detect{|i| i.name == :word_form}.wont_be_nil
      Eson::Language.e0.values.detect{|i| i.name == :variable_identifier}.wont_be_nil
    end
  end

  describe "validate e1" do
    it "should be E1" do
      Eson::Language.e1.class.must_equal Struct::E1
    end
    it "should be aliased" do
      Eson::Language.must_respond_to :verified_special_forms_lang
    end
    it "should contain new rules" do
      rules = Eson::Language.e1.values
      rules.detect{|i| i.name == :unknown_special_form}.must_be_nil
    end
  end

  describe "validate e2" do
    it "should be E2" do
      Eson::Language.e2.class.must_equal Struct::E2
    end
    it "should contain new rules" do
      rules = Eson::Language.e2.values
      rules.detect{|i| i.name == :variable_identifier}.wont_be_nil
    end
  end
end

describe Eson::Language::RuleSeq do

  let(:rule_terminal_seq) {[Eson::Language::RuleSeq::Terminal[:rule_1],
                            Eson::Language::RuleSeq::Terminal[:rule_2x]]}
  let(:rule_seq) {Eson::Language::RuleSeq.
                   new([Eson::Language::RuleSeq::Rule[:rule_1, [], /RU/],
                        Eson::Language::RuleSeq::Rule[:rule_2, [], /LE/],
                        Eson::Language::RuleSeq::Rule[:rule3, :rule_terminal_seq, /RULE/]])}
  
  describe ".new" do
    it "item is a Rule" do
      proc { Eson::Language::RuleSeq.new([Eson::Language::RuleSeq::Rule.new]) }.must_be_silent
    end
    it "items not a Rule" do
      proc { Eson::Language::RuleSeq.new([45]) }.must_raise Eson::Language::RuleSeq::ItemError
    end
  end

  describe "#convert_to_terminal" do
    it "succeeds" do
      original_size = rule_seq.length
      rules = rule_seq.convert_to_terminal(:rule3)
      rules.must_be_instance_of Eson::Language::RuleSeq
      rules.get_rule(:rule3).terminal?.must_equal true
      rules.length.must_equal original_size
    end
  end

  describe "#remove_rules" do
    it "succeeds" do
      rules = rule_seq.remove_rules([:rule_1])
      rules.must_be_instance_of Eson::Language::RuleSeq
      proc {rules.get_rule(:rule_1)}.must_raise Eson::Language::RuleSeq::ItemError
      rules.length.must_equal 2
    end
    it "fails" do
      rule_seq.remove_rules([:not_there]).must_be_nil
    end
  end

  describe "#build_language" do
    it "succeeds" do
      rules = rule_seq.build_language("LANG")
      rules.must_be_instance_of Struct::LANG
    end
  end

  describe "#make_alternation_rule" do
    it "succeeds" do
      rules = rule_seq.make_alternation_rule(:new_rule, [:rule_1, :rule_2])
      rules.must_be_instance_of Eson::Language::RuleSeq
      rules.get_rule(:new_rule).must_be_instance_of Eson::Language::RuleSeq::Rule
      rules.get_rule(:new_rule).nonterminal?.must_equal true
    end
    it "fails" do
      proc {rule_seq.make_alternation_rule(:new_rule, [:not_here, :rule_1])}
        .must_raise Eson::Language::RuleSeq::ItemError
    end
  end

  describe "#make_concatenation_rule" do
    it "succeeds" do
      rules = rule_seq.make_concatenation_rule(:new_rule, [:rule_1, :rule_2])
      rules.must_be_instance_of Eson::Language::RuleSeq
      rules.get_rule(:new_rule).must_be_instance_of Eson::Language::RuleSeq::Rule
      rules.get_rule(:new_rule).nonterminal?.must_equal true
    end
  end
end
