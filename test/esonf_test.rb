require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'

describe "Eson::EsonGrammars::esonf" do

  subject {Eson::EsonGrammars.esonf}
  
  describe "validate_esonf" do
    it "rules have s_attr line_feed" do
      [:program_start, :array_start,
       :element_divider, :declaration_divider]
        .all?{|i| subject.send(i).s_attr.include? :line_feed}
        .must_equal true
    end
    it "rules have s_attr to_s" do
      subject.values.all?{|i| i.s_attr.include? :to_s}
        .must_equal true
    end
  end
end
