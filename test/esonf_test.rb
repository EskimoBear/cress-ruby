require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe "Eson::EsonGrammars::esonf" do

  include TestHelpers
  
  subject {Eson::EsonGrammars.esonf}

  before do
    @ts = get_token_sequence(subject)
    @tree = get_ast(@ts)
  end

  describe "validate_esonf" do
    it "rules have s_attr line_feed" do
      subject.values.all?{|i| i.s_attr.include? :line_feed}
        .must_equal true
    end
    it "rules have :line_start" do
      subject.values.all?{|i| i.s_attr.include? :line_start}
        .must_equal true
    end
    it "rules have s_attr to_s" do
      subject.values.all?{|i| i.s_attr.include? :to_s}
        .must_equal true
    end
  end

  describe "validate_tokens" do
    it "line_feed evaluated" do
      @ts.find_all{|i| i.get_attribute(:line_feed) == true}
        .length.must_equal 16
    end
    it "to_s evaluated" do
      @ts.none?{|i| i.get_attribute(:to_s).nil?}
        .must_equal true
    end
    it "line_start evaluated" do
      @ts.find_all{|i| i.get_attribute(:line_start) == true}
        .length.must_equal 17
    end
  end
end
