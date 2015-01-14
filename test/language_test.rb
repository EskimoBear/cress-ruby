require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/language.rb'

describe Eson::Language do

  describe "validate L0 properties" do
    it "should be a struct" do
      Eson::Language.initial.class.must_equal Struct::L0
    end
    it "should contain rules" do
      rules = Eson::Language.initial.values
      rules.all?{|rule| rule.class == Eson::Language::Rule}.must_equal true
    end
  end
end
