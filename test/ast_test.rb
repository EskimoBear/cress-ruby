require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers'
require_relative '../lib/dote/dote_grammars.rb'

describe AST do

  subject {Dote::DoteGrammars.ast}

  include TestHelpers

  before do
    @ts = get_tokens(subject)
    @parse_tree = get_parse_tree(@ts, subject)
    @ast = get_ast(@parse_tree, subject)
  end

  it "has no alternation rules" do
    @ast.none? do |i|
      i === :alternation
    end.must_equal true
  end

  it "has no option rules" do
    @ast.none? do |i|
      i === :option
    end.must_equal true
  end

  it "has no repetition rules" do
    @ast.none? do |i|
      i === :repetition
    end.must_equal true
  end

  it "reduced array node" do
    array_children = @ast.find{|i| i === :array}.entries
                     .map{|i| i.name}.uniq
    array_children.wont_include :element_list
    array_children.wont_include :element_more
    array_children.wont_include :element_more_once
    array_children.wont_include :element_divider
    array_children.wont_include :array_start
    array_children.wont_include :array_end
    @ast.find{|i| i === :array}.children.
      map{|i| i.name}.wont_include :nullable
  end

  it "reduced program node" do
    program_children = @ast.find{|i| i === :program}.entries
                       .map{|i| i.name}.uniq
    program_children.wont_include :declaration_list
    program_children.wont_include :declaration_more_once
    program_children.wont_include :declaration_divider
    program_children.wont_include :program_start
    program_children.wont_include :program_end
    @ast.find{|i| i === :program}.children.
      map{|i| i.name}.wont_include :nullable
  end

  it "reduced string node" do
    @ast.none?{|i| i === :string}.must_equal true
  end

  it "created :literal_string leaf" do
    @ast.any?{|i| i === :literal_string}.must_equal true
  end

  it "created :interpolated_string tree" do
    @ast.any?{|i| i === :interpolated_string}.must_equal true
  end

  it "created :bind trees" do
    @ast.any?{|i| i === :bind}.must_equal true
    @ast.select{|i| i === :bind}.all?{|i| i.internal?}
      .must_equal true
    @ast.select{|i| i === :bind}.all?{|i| i.degree == 2}
      .must_equal true
    @ast.none?{|i| i === :attribute}.must_equal true
  end

  it "created :apply trees" do
    @ast.any?{|i| i === :apply}.must_equal true
    @ast.select{|i| i === :apply}.all?{|i| i.internal?}
      .must_equal true
    @ast.select{|i| i === :apply}.all?{|i| i.degree == 2}
      .must_equal true
    @ast.none?{|i| i === :call}.must_equal true
  end
end
