require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/rule.rb'

describe Eson::Rule::ParseTree do

  before do
    @terminal_name = :terminal
    @terminal_rule = Eson::Rule
                     .new_terminal_rule(
                       @terminal_name,
                       /rule/)
    @terminal_rule.s_attr.push :s_val
    @production = Eson::Rule.
                        new(
                          :nonterminal,
                          /rule/,
                          false,
                          ["test"])
    @production.s_attr.push :s_val
    @production.i_attr.push :i_val
    @token = @terminal_rule.make_token(:var)
    @token_attr = "s_val value"
    @token.store_attribute(:s_val, @token_attr)
  end

  subject {Eson::Rule::ParseTree}
  let(:tree) {Eson::Rule::ParseTree::Tree}
  
  describe "create_ast" do
    it "incorrect parameter type" do
      proc {subject.new("error_type")}.
        must_raise Eson::Rule::ParseTree::CannotConvertTypeToTree
    end
    describe "empty" do
      before do
        @tree = subject.new
      end
      it "root_is_empty" do
        @tree.empty_tree?.must_equal true
      end
    end
    describe "token" do
      before do
        @tree = subject.new @token
      end
      it "root_is_leaf" do
        @tree.leaf?.must_equal true
      end
      it "root has name" do
        @tree.name.must_equal @token.name
      end
      it "root has attributes" do
        @tree.attribute_list.must_equal [:s_val, :lexeme]
        @tree.get_attribute(:s_val).must_equal @token_attr
        @tree.get_attribute(:lexeme).must_equal :var
      end
      it "root_is_closed" do
        @tree.closed?.must_equal true
      end
      it "root_has_no_parent" do
        @tree.get.parent.empty_tree?.must_equal true
      end
    end
    describe "terminal_rule" do
      it "incorrect parameter type" do
        proc {subject.new(@terminal_rule)}.
          must_raise Eson::Rule::ParseTree::CannotConvertTypeToTree
      end
    end
    describe "production" do
      before do
        @tree = subject.new @production
      end
      it "root is rule" do
        @tree.must_be_instance_of subject
        @tree.root_value.must_equal @production
      end
      it "root has name" do
        @tree.name.must_equal @production.name
      end
      it "root has attributes" do
        @tree.attribute_list.must_equal [:s_val, :i_val]
      end
      it "root is open" do
        @tree.closed?.must_equal false
      end
      it "root is active" do
        @tree.active_node.must_equal @tree.get
      end
      it "root has no parent" do
        @tree.get.parent.empty_tree?.must_equal true
      end
    end
  end

  describe "#insert" do
    before do
      @tree = subject.new @production
    end
    it "node is invalid type" do
      proc {@tree.insert("foo")}
        .must_raise Eson::Rule::ParseTree::CannotConvertTypeToTree
    end
    it "inserted token is leaf of active node" do
      @tree.insert(@token)
      @tree.height.must_equal 2
      child_nodes = @tree.active_node.children
      child_nodes.first.value.name.must_equal @token.name
    end
    it "inserted rule is active node" do
      @tree.insert(@production).insert(@token)
      @tree.height.must_equal 3
      @tree.active_node.value.must_equal @production
    end
    it "inserted rule has root as parent" do
      @tree.insert(@production)
      @tree.active_node.parent.must_equal @tree.get
    end
    it "fails on closed tree" do
      @tree.close_active
      proc {@tree.insert(@rule)}
        .must_raise Eson::Rule::ParseTree::UnallowedMethodForClosedTree
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
          .must_raise Eson::Rule::ParseTree::CannotConvertTypeToTree
      end
    end
  end

  describe "#merge" do
    before do
      @root_tree = subject.new @production
      @tree = subject.new(@production).insert(@token).close_tree
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
      @tree = subject.new @production
      @tree.insert(@production)
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

  describe "#contains?" do
    before do
      @tree = subject.new @production
      @tree.insert(@production)
    end
    it "contains token" do
      @tree.insert(@terminal_rule.make_token(:token))
      @tree.contains?(@terminal_name).must_equal true
    end
    it "doesn't contain token" do
      @tree.contains?(@terminal_name).must_equal false
    end
  end

  describe "#post_order_traversal" do
    before do
      @root_tree = subject.new(@production).insert(@token)
      @tree = subject.new(@production).insert(@token).close_tree
      @root_tree.merge(@tree)
    end
    it "get bottom left" do
      @root_tree.bottom_left_node.value.name.must_equal @token.name
    end
    it "post order trace" do
      @root_tree.post_order_trace
        .must_equal [@token.name, @token.name,
                     @production.name ,@production.name]
    end
  end
end

