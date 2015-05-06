require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/eson_grammars.rb'

describe Eson::EsonGrammars do
  
  subject {Eson::EsonGrammars}

  describe "validate_r0" do
    before do
      @lang = subject.reserved_keys
    end
    it "should contain built rules" do
      @lang.nonterminals.must_be_empty
      @lang.terminals.must_include :special_form_identifier
      @lang.terminals.must_include :unreserved_procedure_identifier
      @lang.terminals.must_include :key_string
    end
  end
  
  describe "validate_e0" do
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
      @lang.nonterminals.must_include :proc_identifier
      @lang.terminals.must_include :word_form
      @lang.terminals.must_include :variable_identifier
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end

  describe "validate_e4" do
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
      @lang.terminals.must_include :string_delimiter
      @lang.nonterminals.must_include :sub_string
      @lang.nonterminals.must_include :sub_string_list
      @lang.nonterminals.must_include :string
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
      subject.method(:e5).must_equal subject.method(:syntax_pass_lang)
    end
    it "should contain new rules" do
      @lang.nonterminals.must_include :value
      @lang.nonterminals.must_include :element_more_once
      @lang.nonterminals.must_include :element_more
      @lang.nonterminals.must_include :element_list
      @lang.nonterminals.must_include :element_set
      @lang.nonterminals.must_include :array
      @lang.nonterminals.must_include :attribute
      @lang.nonterminals.must_include :call
      @lang.nonterminals.must_include :declaration
      @lang.nonterminals.must_include :declaration_more_once
      @lang.nonterminals.must_include :declaration_more
      @lang.nonterminals.must_include :declaration_list
      @lang.nonterminals.must_include :declaration_set
      @lang.nonterminals.must_include :program
    end
    it "should have top rule" do
      @lang.must_respond_to :top_rule
      @lang.top_rule.follow_set.must_include :eof
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end
end

describe Eson::Rule do
    
  describe "#to_s" do
    it "is a terminal rule" do
      Eson::EsonGrammars::e0.comma.to_s.must_match /( := )/ 
    end
    it "is a concatenation rule" do
      Eson::EsonGrammars::e0.variable_identifier.to_s.must_match /( := )/
    end
    it "is a alternation rule" do
      Eson::EsonGrammars::e0.special_form_identifier.to_s.must_match /( := )/
    end
    it "is a repetition rule" do
      Eson::EsonGrammars::e4.sub_string_list.to_s.must_match /( := )/
    end
    it "is an option rule" do
      Eson::EsonGrammars::e5.element_set.to_s.must_match /( := )/
    end
  end
  
  it "is terminal rule" do
    Eson::EsonGrammars::e0.number.partial_status.must_equal false
    first_set = Eson::EsonGrammars::e0.number.first_set
    first_set.must_be_instance_of Array
    first_set.length.must_equal 1
    first_set.must_equal [:number]
  end
  it "has non-terminals" do
    Eson::EsonGrammars::e5.value.partial_status.must_equal false
    first_set = Eson::EsonGrammars::e5.value.first_set
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
      Eson::EsonGrammars::e5.element_set.partial_status.must_equal false
      first_set = Eson::EsonGrammars::e5.element_set.first_set
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
