require_relative '../../utils/respondent'

module TreeTransformations

  extend Respondent

  uses :descendants, :update_height, :set_root

  # Delete the matching node from the tree and retains it's
  # child nodes.
  # @param (see #remove_root)
  def delete_node(tree_match)
    descendants.find{|i| i === tree_match}
      .delete_node(tree_match)
    update_height
    self
  end

  # Apply {delete_node} to all the matching tree nodes.
  # @param (see #remove_root)
  def delete_nodes(tree_match)
    descendants.find_all{|i| i === tree_match}
      .each{|i| i.delete_node(tree_match)}
    update_height
    self
  end

  # Delete the matching tree i.e. the node and all it's child nodes.
  # Replaces the tree with the empty tree if no tree_match is not given
  # or if the root is matched.
  # @param (see #remove_root)
  # @return [ParseTree]
  # @see delete_node
  def delete_tree(tree_match=nil)
    if tree_match.nil? || self === tree_match
      Parser::ParseTree::Tree.new
    else
      ex_tree = descendants.detect{|i| i === tree_match}
      ex_tree_index = ex_tree.parent.children.find_index{|i| i === tree_match}
      ex_tree.parent.children.delete_at(ex_tree_index)
      self
    end
  end

  # Replace a root node with it's children
  # @param tree_match [Symbol, nil] case match for Tree
  # @return [ParseTree, Tree] the modified root tree
  def remove_root(tree_match=nil)
    if tree_match.nil?
      reduce_root
    elsif self === tree_match
      reduce_root_tree_var(tree_match)
    else
      tree = find{|i| i === tree_match}.remove_root(tree_match)
      update_height
      tree
    end
  end

  # When the root of tree_match has one child make the child the new root
  # of the ParseTree or Tree. When tree_match is nil the root of the
  # ParseTree will be matched for reduction.
  # @param (see #remove_root)
  # @return (see #remove_root)
  def reduce_root(tree_match=nil)
    if tree_match.nil?
      reduce_root_tree_var(self.name)
    else
      tree = find{|i| i === tree_match}.reduce_root
      update_height
      tree
    end
  end

  # FIXME accesses @root_tree and @height directly
  # @param (see #remove_root)
  def reduce_root_tree_var(tree_match)
    if self === tree_match
      if degree == 1
        new_root = children.first
        new_root.parent = Parser::ParseTree::Tree.new
        @root_tree = new_root
        @height = @height - 1
        self
      end
    end
  end

  # Apply {#remove_root} to all the matching tree nodes
  # @param (see #remove_root)
  def remove_roots(tree_match)
    if self === tree_match
      reduce_root_tree_var(tree_match)
    end
    self.select{|i| i === tree_match}
      .each{|i| i.remove_root(tree_match)}
    update_height
    self
  end

  # Apply {#reduce_root} to all matching tree nodes
  # @param (see #remove_root)
  def reduce_roots(tree_match)
    reduce_root_tree_var(tree_match)
    post_order_entries = []
    self.post_order_traversal{|i| post_order_entries.push i}
    post_order_entries.select{|i| i === tree_match}
      .each{|tm| tm.reduce_root}
    update_height
   self
  end

  # Replace the root with the rule in new_root
  # @param obj [#to_tree]
  # @return [ParseTree] the modified tree
  def replace_root(obj)
    set_root(obj, children)
  end
end
