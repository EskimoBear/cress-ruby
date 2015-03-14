require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/abstract_syntax_tree'

describe Eson::Language::AbstractSyntaxTree do

  subject {Eson::Language::AbstractSyntaxTree}
  let(:tree) {Eson::Language::AbstractSyntaxTree::Tree}
  
  describe "create an AST" do
    before do
      @root_rule = Eson::FormalLanguages::e5.variable_identifier
      @tree = subject.new(@root_rule)
    end 
    it "root is rule" do
      @tree.must_be_instance_of subject
      @tree.root_value.must_equal @root_rule
    end
    it "root is open" do
      @tree.open?.must_equal true
      @tree.closed?.must_equal false
    end
    it "root is active" do
      @tree.active_node.must_equal @tree.get 
      @tree.active_node.must_be_instance_of tree
    end
    it "incorrect parameter type" do
      proc {subject.new("error_type")}.
        must_raise Eson::Language::AbstractSyntaxTree::TreeInitializationError
    end
  end

  describe "#insert" do
    before do
      @root_rule = Eson::FormalLanguages::e5.variable_identifier
      @ast = Eson::Language::AbstractSyntaxTree.new(@root_rule)
      @token = Eson::Tokenizer::TokenSeq::Token.new(",", :comma)
      @rule = Eson::FormalLanguages::e5.variable_identifier
    end  
    it "node is invalid type" do
      proc {@ast.insert("poo")}.must_raise Eson::Language::AbstractSyntaxTree::TreeInsertionError
    end
    it "token is leaf of active node" do
      @ast.insert(@token)
      @ast.active_node.children.must_include @token
    end
    it "rule is new active node" do
      @ast.insert(@rule)
      @ast.active_node.rule.must_equal @rule
    end
  end
end

