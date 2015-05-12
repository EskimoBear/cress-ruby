require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe "Eson::EsonGrammars::esonf" do

  include TestHelpers
  
  subject {Eson::EsonGrammars.esonf}
  
  describe "validate_esonf" do
    it "rules have s_attr line_feed" do
      subject.values.all?{|i| i.s_attr.include? :line_feed}
        .must_equal true
    end
    it "rules have s_attr to_s" do
      subject.values.all?{|i| i.s_attr.include? :to_s}
        .must_equal true
    end
  end

  describe "validate_tokens" do
    before do
      @ts = get_token_sequence(subject)
    end
    it "correct line_feed" do
      @ts.find_all{|i| i.get_attribute(:line_feed) == true}
        .length.must_equal 16
    end
  end
end
