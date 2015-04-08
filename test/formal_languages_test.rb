require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/formal_languages.rb'

describe Eson::FormalLanguages do
  
  subject {Eson::FormalLanguages}
  
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
      @lang.must_respond_to :special_form
      @lang.must_respond_to :proc_identifier
      @lang.must_respond_to :word_form
      @lang.must_respond_to :variable_identifier
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end
  
  describe "validate_e1" do
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

  
  describe "validate_e2" do
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

  describe "validate_e3" do
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
      @lang.wont_respond_to :empty_word
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
      subject.method(:e5).must_equal subject.method(:syntax_pass_lang)
    end
    it "should contain new rules" do
      @lang.values.each{|i| puts "#{i.name} - has follow_set #{i.follow_set}\n #{i}" }
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
      @lang.top_rule.follow_set.must_include :eof
    end
    it "has no partial rules" do
      @lang.values.none?{|x| x.partial_status}.must_equal true
    end
  end 
end

describe Eson::Language::RuleSeq::Rule do
    
  describe "#to_s" do
    it "is a terminal rule" do
      Eson::FormalLanguages::e0.comma.to_s.must_match /( := )/ 
    end
    it "is a concatenation rule" do
      Eson::FormalLanguages::e0.variable_identifier.to_s.must_match /( := )/
    end
    it "is a alternation rule" do
      Eson::FormalLanguages::e0.special_form.to_s.must_match /( := )/
    end
    it "is a repetition rule" do
      Eson::FormalLanguages::e4.sub_string_list.to_s.must_match /( := )/
    end
    it "is an option rule" do
      Eson::FormalLanguages::e5.element_set.to_s.must_match /( := )/
    end
  end
  
  it "is terminal rule" do
    Eson::FormalLanguages::e0.number.partial_status.must_equal false
    first_set = Eson::FormalLanguages::e0.number.first_set
    first_set.must_be_instance_of Array
    first_set.length.must_equal 1
    first_set.must_equal [:number]
  end
  it "has non-terminals" do
    Eson::FormalLanguages::e5.value.partial_status.must_equal false
    first_set = Eson::FormalLanguages::e5.value.first_set
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
      Eson::FormalLanguages::e5.element_set.partial_status.must_equal false
      first_set = Eson::FormalLanguages::e5.element_set.first_set
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

