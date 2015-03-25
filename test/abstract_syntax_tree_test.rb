require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/formal_languages'

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
    it "root has no parent" do
      @tree.get.parent.must_be_nil
    end
    it "incorrect parameter type" do
      proc {subject.new("error_type")}.
        must_raise Eson::Language::AbstractSyntaxTree::TreeInitializationError
    end
  end

  describe "#insert" do
    before do
      @root_rule = Eson::FormalLanguages::e5.comma
      @ast = Eson::Language::AbstractSyntaxTree.new(@root_rule) 
      @rule = Eson::FormalLanguages::e5.variable_identifier
      @token = @rule.make_token(:var)
    end  
    it "node is invalid type" do
      proc {@ast.insert("poo")}
        .must_raise Eson::Language::AbstractSyntaxTree::TreeInsertionError
    end
    it "inserted token is leaf of active node" do
      @ast.insert(@token)
      @ast.active_node.children.must_include @token
    end
    it "inserted rule is active node" do
      @ast.insert(@rule)
      @ast.active_node.rule.must_equal @rule
    end
    it "inserted rule has root as parent" do
      @ast.insert(@rule)
      @ast.active_node.parent.must_equal @ast.get
    end
    it "fails on closed tree" do
      @ast.close_active
      proc {@ast.insert(@rule)}
        .must_raise Eson::Language::AbstractSyntaxTree::ClosedTreeError
    end
  end

  describe "#close_active" do
    before do
      @root_rule = Eson::FormalLanguages::e5.comma
      @ast = Eson::Language::AbstractSyntaxTree.new(@root_rule)
      @ast.insert(Eson::FormalLanguages::e5.variable_identifier)
      @ast.insert(@root_rule.make_token(:var))
      @rule = Eson::FormalLanguages::e5.variable_identifier
      @token = @rule.make_token(:var)
    end
    it "active node is closed" do
      @ast.close_active
      @ast.active_node.must_equal @ast.get
    end
    it "tree is closed" do
      @ast.close_active
      @ast.close_active
      @ast.closed?.must_equal true
    end
  end
end

