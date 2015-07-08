require_relative './test_helpers'
require_relative '../lib/dote/rule.rb'

describe TreeTransformations do

  include TestHelpers

  subject {Parser::ParseTree}
  
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
