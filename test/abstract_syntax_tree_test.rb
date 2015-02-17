require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/abstract_syntax_tree'

describe Eson::AbstractSyntaxTree do

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

  describe "#insert_node_concatenation_rule" do
    before do
      @ast = Eson::AbstractSyntaxTree.new(Eson::Language.e5)
      @invalid_token = Eson::Tokenizer::TokenSeq::Token.new(",", :comma)
      @valid_token = Eson::Tokenizer::TokenSeq::Token.new("{", :program_start)
      @invalid_rule = Eson::Language::e0.variable_identifier
    end
    
    it "node is invalid type" do
      proc {@ast.insert("poo")}.must_raise Eson::AbstractSyntaxTree::TreeInsertionError
    end
    it "node is an invalid Token" do
      proc {@ast.insert(@invalid_token)}.must_raise Eson::AbstractSyntaxTree::TreeInsertionError
      @ast.children.must_be_empty
    end
    it "node is valid Token" do
      @ast.insert(@valid_token)
      @ast.children.wont_be_empty
    end
  end
end

