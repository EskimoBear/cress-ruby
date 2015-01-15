require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/language.rb'

describe Eson::Language do

  describe "validate e0 properties" do
    it "should be a struct" do
      Eson::Language.e0.class.must_equal Struct::E0
    end
    it "should contain rules" do
      rules = Eson::Language.e0.values
      rules.all?{|rule| rule.class == Eson::Language::Rule}.must_equal true
    end
    it "sequence is empty" do
    end
  end
end
