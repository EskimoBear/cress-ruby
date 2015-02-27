require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/language.rb'

describe Eson::Language do

  subject {Eson::Language}
  
  describe "validate e0" do
    before do
      @lang = subject.e0
    end
    it "should be E0" do
      @lang.class.must_equal Struct::E0
    end
    it "should be aliased" do
      subject.method(:e0).must_equal subject.method(:tokenizer_lang)
    end
    it "should contain built rules" do
      @lang.must_respond_to :special_form
      @lang.must_respond_to :proc_identifier
      @lang.must_respond_to :word_form
      @lang.must_respond_to :variable_identifier
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate e1" do
    before do
      @lang = subject.e1
    end
    it "should be E1" do
      @lang.class.must_equal Struct::E1
    end
    it "should be aliased" do
      subject.method(:e1).must_equal subject.method(:verified_special_forms_lang)
    end
    it "should contain new rules" do
      @lang.wont_respond_to :unkown_special_form
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate e2" do
    before do
      @lang = subject.e2
    end
    it "should be E2" do
      @lang.class.must_equal Struct::E2
    end
    it "should be aliased" do
      subject.method(:e2).must_equal subject.method(:tokenize_variable_identifier_lang)
    end
    it "should contain new rules" do
      @lang.must_respond_to :key
      @lang.wont_respond_to :let
      @lang.wont_respond_to :ref
      @lang.wont_respond_to :doc
      @lang.wont_respond_to :special_form
      @lang.wont_respond_to :proc_prefix
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate e3" do
    before do
      @lang = subject.e3
    end
    it "should be E3" do
      @lang.class.must_equal Struct::E3
    end
    it "should be aliased" do
      subject.method(:e3).must_equal subject.method(:tokenize_word_form_lang)
    end
    it "should contain new rules" do
      @lang.must_respond_to :word_form
      @lang.wont_respond_to :other_chars
      @lang.wont_respond_to :variable_prefix
      @lang.wont_respond_to :word
      @lang.wont_respond_to :whitespace
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate e4" do
    before do
      @lang = subject.e4
    end
    it "should be E4" do
      @lang.class.must_equal Struct::E4
    end
    it "should be aliased" do
      subject.method(:e4).must_equal subject.method(:label_sub_string_lang)
      subject.method(:e4).must_equal subject.method(:insert_string_delimiter_lang)
    end
    it "should contain new rules" do
      @lang.must_respond_to :sub_string
      @lang.must_respond_to :string_delimiter
      @lang.must_respond_to :sub_string_list
      @lang.must_respond_to :string
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate_e5" do
    before do
      @lang = subject.e5
    end
    it "should be E5" do
      @lang.class.must_equal Struct::E5
    end
    it "should be aliased" do
    end
    it "should contain new rules" do
      @lang.must_respond_to :value
      @lang.must_respond_to :element_more_once
      @lang.must_respond_to :element_more
      @lang.must_respond_to :element_list
      @lang.must_respond_to :element_set
      @lang.must_respond_to :array
      @lang.must_respond_to :declaration
      @lang.must_respond_to :declaration_more_once
      @lang.must_respond_to :declaration_more
      @lang.must_respond_to :declaration_list
      @lang.must_respond_to :declaration_set
      @lang.must_respond_to :program
    end
    it "should have top rule" do
      @lang.must_respond_to :top_rule
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end    
end

describe Eson::Language::RuleSeq do

  subject {Eson::Language::RuleSeq}
  let(:rule) {Eson::Language::RuleSeq::Rule}
  let(:terminal) {Eson::Language::RuleSeq::Terminal}
  let(:rule_terminal_seq) {[terminal[:rule_1],
                            terminal[:rule_2]]}
  let(:rule_seq) {subject.new([rule.new(:rule_1, [], /RU/),
                               rule.new(:rule_2, [], /LE/)])}
  
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
      @first_set.must_include @new_rule.name
      @new_rule.nullable.must_equal false
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
      Eson::Language::e0.to_s.must_match /has the following production rules/
    end
  end
  
  describe "#make_alternation_rule" do
    it "has correct properties" do
      @rules = rule_seq.make_alternation_rule(:new_rule, [:rule_1, :rule_2])
      @new_rule = @rules.get_rule(:new_rule)
      @rules.must_be_instance_of subject
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.nullable.must_equal false
      @new_rule.first_set.must_include :rule_1
      @new_rule.first_set.must_include :rule_2
      @new_rule.partial_status.must_equal false
    end
    describe "with undefined rules" do
      before do
        @rules = rule_seq.make_alternation_rule(:new_rule, [:rule_2, :undefined])
        @new_rule = @rules.get_rule(:new_rule)
        @new_rule_terms = @new_rule.sequence
        @term_names = @new_rule_terms.map{|x| x.rule_name}
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
      @new_rule.nullable.must_equal false
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
      @new_rule.must_be_instance_of rule
      @new_rule.nonterminal?.must_equal true
      @new_rule.nullable.must_equal true
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
      @new_rule.nullable.must_equal true
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
    
  describe "#to_s" do
    it "is a terminal rule" do
      Eson::Language::e0.comma.to_s.must_match /( := )/ 
    end
    it "is a concatenation rule" do
      Eson::Language::e0.variable_identifier.to_s.must_match /( := )/
    end
    it "is a alternation rule" do
      Eson::Language::e0.special_form.to_s.must_match /( := )/
    end
    it "is a repetition rule" do
      Eson::Language::e4.sub_string_list.to_s.must_match /( := )/
    end
    it "is an option rule" do
      Eson::Language::e5.element_set.to_s.must_match /( := )/
    end
  end
  
  it "is terminal rule" do
    Eson::Language::e0.number.partial_status.must_equal false
    first_set = Eson::Language::e0.number.first_set
    first_set.must_be_instance_of Array
    first_set.length.must_equal 1
    first_set.must_equal [:number]
  end
  it "has non-terminals" do
    Eson::Language::e5.value.partial_status.must_equal false
    first_set = Eson::Language::e5.value.first_set
    first_set.must_be_instance_of Array
    first_set.length.must_equal 8
    first_set.must_include :variable_identifier
    first_set.must_include :true
    first_set.must_include :false
    first_set.must_include :null
    first_set.must_include :string_delimiter
    first_set.must_include :number
    first_set.must_include :array_start
    first_set.must_include :program_start
  end
  describe "starts with nonterminal" do
    it "is option rule" do
      Eson::Language::e5.element_set.partial_status.must_equal false
      first_set = Eson::Language::e5.element_set.first_set
      first_set.must_be_instance_of Array
      first_set.length.must_equal 9
      first_set.must_include :variable_identifier
      first_set.must_include :true
      first_set.must_include :false
      first_set.must_include :null
      first_set.must_include :string_delimiter
      first_set.must_include :number
      first_set.must_include :array_start
      first_set.must_include :program_start
      first_set.must_include :nullable
    end
  end
end
