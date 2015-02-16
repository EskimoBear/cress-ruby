require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/abstract_syntax_tree'

describe Eson::AbstractSyntaxTree do

  before do
    @ast = Eson::AbstractSyntaxTree.new(Eson::Language.e5)
    @token = Eson::Tokenizer::TokenSeq::Token.new(",", :comma)
    @rule = Eson::Language::e0.variable_identifier
  end

  describe "create an e5 tree" do
    before do
      @tree = Eson::AbstractSyntaxTree.new(Eson::Language.e5)
    end
    it "root is top rule" do 
      @tree.must_be_instance_of Eson::AbstractSyntaxTree
      @tree.root_value.must_equal Eson::Language.e5.top_rule
    end
    it "root is open" do
      @tree.open?.must_equal true
      @tree.closed?.must_equal false
    end
    it "root is active" do
      @tree.active_node.must_equal @tree.get 
      @tree.active_node.must_be_instance_of Eson::AbstractSyntaxTree::Tree
    end
  end

  describe "#add_node" do
    it "node is invalid type" do
      proc {@ast.add_node("poo")}.must_raise Eson::AbstractSyntaxTree::TreeInsertionError
    end
    it "node is a Rule" do
      @ast.add_node(@rule)
      @ast.children.wont_be_empty
    end
    it "node is a Token" do
      @ast.add_node(@token)
      @ast.children.wont_be_empty
    end
    it "node is invalid token" do
      skip
      token = Eson::Tokenizer::TokenSeq::Token.new(",", :comma)
      proc {@ast.add_node(token)}.must_raise Eson::AbstractSyntaxTree::TreeInsertionError
      @ast.children.must_be_empty
    end
  end
end

