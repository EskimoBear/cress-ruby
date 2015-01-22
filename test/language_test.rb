require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/language.rb'

describe Eson::Language do
  
  describe "validate e0 properties" do
    it "should be a struct" do
      Eson::Language.e0.class.must_equal Struct::E0
    end
    it "should be aliased" do
      Eson::Language.must_respond_to :tokenizer_lang
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
      rules.detect{|i| i.name == :unknown_special_form}.must_be_nil true
    end
  end

  describe "validate e2" do
    it "should be E2" do
      Eson::Language.e2.class.must_equal Struct::E2
    end
    it "should contain new rules" do
      rules = Eson::Language.e2.values
      rules.detect{|i| i.name == :variable_prefix}.must_be_nil
      rules.detect{|i| i.name == :variable_identifier}.wont_be_nil true
    end
  end
end

describe Eson::Language::RuleSeq do

  let(:rule_seq) {Eson::Language::RuleSeq.new( [Eson::Language::Rule[:rule_1,[],/RU/],
                                                Eson::Language::Rule[:rule_2,[],/LE/]])}
  
  describe ".new" do
    it "item is a Rule" do
      proc { Eson::Language::RuleSeq.new([Eson::Language::Rule.new]) }.must_be_silent
    end
    it "items not a Rule" do
      proc { Eson::Language::RuleSeq.new([45]) }.must_raise Eson::Language::RuleSeqItemError
    end
  end

  describe "#combine_rules" do
    it "succeeds" do
      rules = rule_seq.combine_rules([:rule_1, :rule_2], :rule_new)
      rules.must_be_instance_of Eson::Language::RuleSeq
      rules.detect{|i| i.name == :rule_new}.wont_be_nil
      rules.length.must_equal 3
    end
    it "fails" do
      rule_seq.combine_rules([:rule_1, :not_there], :rule_new).must_be_nil
    end
  end

  describe "#remove_rules" do
    it "succeeds" do
      rules = rule_seq.remove_rules([:rule_1])
      rules.must_be_instance_of Eson::Language::RuleSeq
      rules.detect{|i| i.name == :rule_1}.must_be_nil
      rules.length.must_equal 1
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
end
