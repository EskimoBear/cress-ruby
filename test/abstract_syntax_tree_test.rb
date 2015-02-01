require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/abstract_syntax_tree'

describe Eson::AbstractSyntaxTree do

  before do
    @ast = Eson::AbstractSyntaxTree.new(Eson::Language.e5)
  end

  it "get an empty tree" do
    @ast.must_be_instance_of Eson::AbstractSyntaxTree
  end

  describe "#add_node" do
    it "add invalid node" do
      proc {@ast.add_node("poo")}.must_raise Eson::TreeInsertionError
    end
    it "add a token" do
      token = Eson::Tokenizer::TokenSeq::Token.new(",", :comma)
      @ast.add_node(token)
      @ast.children.wont_be_empty
    end
    it "add a rule" do
      rule = Eson::Language::e0.variable_identifier
      @ast.add_node(rule)
      @ast.children.wont_be_empty
    end
  end
end

