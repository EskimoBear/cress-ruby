require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/formal_languages'

describe Eson::Language::AbstractSyntaxTree do

  before do
    @terminal_rule = Eson::FormalLanguages::e5.variable_identifier
    @nonterminal_rule = Eson::FormalLanguages::e5.string
    @token = @terminal_rule.make_token(:var)
  end

  subject {Eson::Language::AbstractSyntaxTree}
  let(:tree) {Eson::Language::AbstractSyntaxTree::Tree}
  
  describe "create_ast" do
    it "incorrect parameter type" do
      proc {subject.new("error_type")}.
        must_raise Eson::Language::AbstractSyntaxTree::InitializationError
    end
    describe "empty" do
      before do
        @tree = subject.new
      end
      it "root_is_empty" do
        @tree.empty?.must_equal true
      end
    end
    describe "token" do
      before do
        @tree = subject.new @token
      end
      it "root_is_leaf" do
        @tree.leaf?.must_equal true
      end
      it "root_is_closed" do
        @tree.closed?.must_equal true
      end
      it "root_has_no_parent" do
        @tree.get.parent.must_be_nil
      end
    end
    describe "terminal_rule" do
      it "incorrect parameter type" do
        proc {subject.new(@terminal_rule)}.
          must_raise Eson::Language::AbstractSyntaxTree::InitializationError
      end
    end
    describe "nonterminal_rule" do
      before do
        @tree = subject.new @nonterminal_rule
      end
      it "root is rule" do
        @tree.must_be_instance_of subject
        @tree.root_value.must_equal @nonterminal_rule
      end
      it "root is open" do
        @tree.closed?.must_equal false
      end
      it "root is active" do
        @tree.active_node.must_equal @tree.get
      end
      it "root has no parent" do
        @tree.get.parent.must_be_nil
      end
    end
  end

  describe "#insert" do
    before do
      @tree = subject.new @nonterminal_rule
    end
    it "node is invalid type" do
      proc {@tree.insert("foo")}
        .must_raise Eson::Language::AbstractSyntaxTree::InsertionError
    end
    it "inserted token is leaf of active node" do
      @tree.insert(@token)
      @tree.height.must_equal 2
      child_nodes = @tree.active_node.children
      child_nodes.first.value.name.must_equal @token.name
    end
    it "inserted rule is active node" do
      @tree.insert(@terminal_rule).insert(@token)
      @tree.height.must_equal 3
      @tree.active_node.value.must_equal @terminal_rule
    end
    it "inserted rule has root as parent" do
      @tree.insert(@terminal_rule)
      @tree.active_node.parent.must_equal @tree.get
    end
    it "fails on closed tree" do
      @tree.close_active
      proc {@tree.insert(@rule)}
        .must_raise Eson::Language::AbstractSyntaxTree::ClosedTreeError
    end
    describe "empty_tree" do
      before do
        @empty_tree = subject.new
      end
      it "root inserted" do
        @empty_tree.insert(@token)
        @empty_tree.root_value.must_equal @token
        @empty_tree.height.must_equal 1
      end
      it "root insertion failed" do
        proc {@empty_tree.insert("error_string")}
          .must_raise Eson::Language::AbstractSyntaxTree::InsertionError
      end
    end
  end

  describe "#merge" do
    before do
      @root_tree = subject.new @nonterminal_rule
      @tree = subject.new(@nonterminal_rule).insert(@token).close_tree
      @root_tree.merge(@tree)
    end
    it "tree is child node" do
      @root_tree.has_child?(@tree.root_value.name).must_equal true
    end
    it "height is updated" do
      @root_tree.height.must_equal 3
    end
    it "levels incremented" do
      @root_tree.level.must_equal 1
      @tree.level.must_equal 2
      @tree.children.first.level.must_equal 3
    end
  end
  
  describe "#close_active" do
    before do
      @tree = subject.new @nonterminal_rule
      @tree.insert(Eson::FormalLanguages::e5.variable_identifier)
      @tree.insert(@token)
    end
    it "active node is closed" do
      @tree.close_active
      @tree.active_node.must_equal @tree.get
    end
    it "tree is closed" do
      @tree.close_active
      @tree.close_active
      @tree.closed?.must_equal true
    end
  end
end

