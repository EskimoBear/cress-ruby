require_relative './test_helpers'
require_relative '../lib/dote/rule.rb'

describe Parser::ParseTree do

  include TestHelpers

  before do
    @terminal_rule = get_sample_terminal
    @terminal_rule.s_attr.push :s_val
    @production = get_sample_production
    @production.s_attr.push :s_val
    @production.i_attr.push :i_val
    @token = @terminal_rule.make_token(:var)
    @token_attr = "s_val value"
    @token.store_attribute(:s_val, @token_attr)
  end

  subject {Parser::ParseTree}
  let(:tree) {Parser::ParseTree::Tree}

  describe "create_ast" do
    it "incorrect parameter type" do
      proc {subject.new("error_type")}.
        must_raise Parser::ParseTree::CannotConvertTypeToTree
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
          must_raise Parser::ParseTree::CannotConvertTypeToTree
      end
    end
    describe "production" do
      before do
        @tree = subject.new @production
      end
      it "root has name" do
        @tree.name.must_equal @production.name
      end
      it "root has attributes" do
        @tree.attribute_list.must_equal [:s_val, :production_type, :i_val]
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

  describe "#===" do
    before do
      @tree = subject.new @production
    end
    it "matches name" do
      @tree.must_be :===, @production.name
    end
    it "matches :production_type" do
      @tree.must_be :===, :alternation
    end
  end

  describe "#insert" do
    before do
      @tree = subject.new @production
    end
    it "node is invalid type" do
      proc {@tree.insert("foo")}
        .must_raise Parser::ParseTree::CannotConvertTypeToTree
    end
    it "inserted token is leaf of active node" do
      @tree.insert(@token)
      @tree.height.must_equal 2
      child_nodes = @tree.active_node.children
      child_nodes.first.name.must_equal @token.name
    end
    it "inserted rule is active node" do
      @tree.insert(@production).insert(@token)
      @tree.height.must_equal 3
      @tree.active_node.name.must_equal @production.name
    end
    it "inserted rule has root as parent" do
      @tree.insert(@production)
      @tree.active_node.parent.must_equal @tree.get
    end
    it "fails on closed tree" do
      @tree.close_active
      proc {@tree.insert(@rule)}
        .must_raise Parser::ParseTree::UnallowedMethodForClosedTree
    end
    describe "empty_tree" do
      before do
        @empty_tree = subject.new
      end
      it "root inserted" do
        @empty_tree.insert(@token)
        @empty_tree.name.must_equal @token.name
        @empty_tree.height.must_equal 1
      end
      it "root insertion failed" do
        proc {@empty_tree.insert("error_string")}
          .must_raise Parser::ParseTree::CannotConvertTypeToTree
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
      @root_tree.has_child?(@tree.name).must_equal true
    end
    it "parent updated" do
      tree = @root_tree.children.first
      tree.parent.wont_be :empty_tree?
      tree.parent.must_be_same_as @root_tree.get
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
      @tree.contains?(@terminal_rule.name).must_equal true
    end
    it "doesn't contain token" do
      @tree.contains?(@terminal_rule.name).must_equal false
    end
  end

  describe "#post_order_traversal" do
    before do
      @root_tree = subject.new(@production).insert(@token)
      @tree = subject.new(@production).insert(@token).close_tree
      @root_tree.merge(@tree)
    end
    it "get bottom left" do
      @root_tree.bottom_left_node.name.must_equal @token.name
    end
    it "post order trace" do
      @root_tree.post_order_trace
        .must_equal [@token.name, @token.name,
                     @production.name ,@production.name]
    end
  end

  describe "#each" do
    before do
      @root_tree = subject.new(@production).insert(@token).insert(@token)
      @tree = subject.new(@production).insert(@token).close_tree
      @root_tree.merge(@tree)
      @all_names = @root_tree.each_with_object([]) do |i, a|
        a.push i.name
      end
    end
    it "yields all members" do
      @all_names.length.must_equal 5
      @all_names.all?{|i| i.instance_of?(Symbol)}.must_equal true
    end
    it "yields in pre-order" do
      @all_names.must_equal [@production.name, @token.name, @token.name,
                             @production.name, @token.name]
    end
  end

  describe "#reduce_root" do
    before do
      @child_prod = @production.clone
      @child_prod.name = :child_prod
      @redundant_root_tree = subject.new(@production).insert(@child_prod).insert(@token)
    end
    it "with ParseTree root" do
      result = @redundant_root_tree.reduce_root
      result.must_be :===, @child_prod.name
    end
    it "height decremented" do
      original_height = @redundant_root_tree.height
      @redundant_root_tree.reduce_root.height
        .must_equal (original_height - 1)
    end
    it "retains active node" do
      original_active = @redundant_root_tree.active_node
      @redundant_root_tree.reduce_root.active_node.must_equal original_active
    end
    it "with tree name" do
      original_height = @redundant_root_tree.height
      result = @redundant_root_tree.reduce_root(@child_prod.name)
      result.must_be :===, @token.name
      @redundant_root_tree.get.must_be :===, @production.name
      @redundant_root_tree.height.must_equal (original_height - 1)
    end
    it "with tree :production_type" do
      original_height = @redundant_root_tree.height
      result = @redundant_root_tree.reduce_root(:alternation)
      result.must_be :===, @child_prod.name
      @redundant_root_tree.get.must_be :===, @child_prod.name
      @redundant_root_tree.height.must_equal (original_height -1)
    end
    it "reduce all matching roots" do
      result = @redundant_root_tree.reduce_roots(:alternation)
      result.must_be :===, @token.name
      result.must_be_same_as @redundant_root_tree
      result.height.must_equal 1
    end
  end

  describe "#remove_root" do
    before do
      @child_prod = @production.clone
      @child_prod.name = :child_prod
      @single_root_tree = subject.new(@child_prod).insert(@token)
                      .insert(@token).insert(@token).close_tree
      @redundant_root_tree = subject.new(@production)
                             .merge(@single_root_tree)
      @triple_root_tree = subject.new(@production).insert(@production)
                          .insert(@production).insert(@token)
                          .insert(@token).insert(@token)
      @child_token = @token.clone
      @child_token.name = :child_token
      @ordering_tree = subject.new(@production).insert(@production)
                       .insert(@token).insert(@production).insert(@child_token)
                       .insert(@child_token).close_active.insert(@token)
    end
    it "with single possible root" do
      @single_root_tree.remove_root.must_equal nil
    end
    it "with possible replacement root" do
      original_height = @redundant_root_tree.height
      result = @redundant_root_tree.remove_root
      result.must_be :===, @child_prod.name
      result.height.must_equal (original_height - 1)
    end
    it "with tree name" do
      original_height = @redundant_root_tree.height
      result = @redundant_root_tree.remove_root(@production.name)
      result.must_be :===, @child_prod.name
      result.height.must_equal (original_height - 1)
    end
    it "with :production_type" do
      tree = subject.new(@child_prod).insert(@production)
             .insert(@production).insert(@token)
             .insert(@token).insert(@token)
    end
    it "matching Tree" do
      original_height = @redundant_root_tree.height
      result = @redundant_root_tree.remove_root(@child_prod.name)
      @redundant_root_tree.children.find{|i| i === @child_prod.name}
        .must_be_nil
      @redundant_root_tree.children.first.parent
        .must_be :===, @production.name
      @redundant_root_tree.height.must_equal (original_height - 1)
    end
    it "remove_roots" do
      result = @triple_root_tree.remove_roots(@production.name)
      result.must_be_same_as @triple_root_tree#@production.name
      @triple_root_tree.degree.must_equal 3
      @triple_root_tree.height.must_equal 2
    end
    it "retain ParseTree root" do
      result = @ordering_tree.remove_roots(@production.name)
      result.must_be :===, @production.name
    end
    it "retain insertion ordering" do
      result = @ordering_tree.remove_roots(@production.name)
      result.must_be :has_children?,
                     [@token.name, @child_token.name,
                      @child_token.name, @token.name]
    end
  end

  describe "#delete_node" do
    before do
      @single_root_tree = subject.new(@production).insert(@token)
                          .insert(@token).insert(@token)
                          .insert(@production).insert(@token)
    end
    it "delete leaf" do
      degree = @single_root_tree.degree
      @single_root_tree.delete_node(@token.name)
      @single_root_tree.degree.must_equal degree - 1
    end
    it "delete tree node root" do
      original_height = @single_root_tree.height
      @single_root_tree.delete_node(@production.name)
      @single_root_tree.height.must_equal original_height - 1
      @single_root_tree.must_be :has_children?,
                                [@token.name, @token.name,
                                 @token.name, @token.name]
    end
    it "delete leaves" do
      original_height = @single_root_tree.height
      @single_root_tree.delete_nodes(@token.name)
      @single_root_tree.degree.must_equal 1
      @single_root_tree.height.must_equal original_height - 1
    end
    it "delete nodes" do
      @single_root_tree.close_active.insert(@production)
      original_height = @single_root_tree.height
      @single_root_tree.delete_nodes(@production.name)
      @single_root_tree.height.must_equal original_height - 1
      @single_root_tree.must_be :has_children?,
                                [@token.name, @token.name,
                                 @token.name, @token.name]
    end
  end
end
