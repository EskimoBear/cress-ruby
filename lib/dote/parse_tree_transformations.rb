require_relative '../../utils/respondent'

module TreeTransformations

  extend Respondent

  uses :update_height

  # Delete the matching node from the tree
  # @param (see #remove_root)
  def delete_node(tree_match)
    descendants.find{|i| i === tree_match}
      .delete_node(tree_match)
    update_height
    self
  end

  # @return [Array<Tree>] all nodes excluding the root
  def descendants
    @root_tree.entries.drop(1)
  end

  # Apply {delete_node} to all the matching tree nodes.
  # @param (see #remove_root)
  def delete_nodes(tree_match)
    descendants.find_all{|i| i === tree_match}
      .each{|i| i.delete_node(tree_match)}
    update_height
    self
  end

  # Replace a root node with it's children
  # @param tree_match [Symbol, nil] case match for Tree
  # @return [ParseTree, Tree] the modified root tree
  def remove_root(tree_match=nil)
    if tree_match.nil?
      reduce_root
    elsif @root_tree === tree_match
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
      reduce_root_tree_var(@root_tree.name)
    else
      tree = find{|i| i === tree_match}.reduce_root
      update_height
      tree
    end
  end

  # @param (see #remove_root)
  def reduce_root_tree_var(tree_match)
    if @root_tree === tree_match
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
    if @root_tree === tree_match
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
end
