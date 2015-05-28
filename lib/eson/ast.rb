module AST

  def convert_to_ast(tree)
    remove_alternation_rules(tree)
    remove_option_rules(tree)
    remove_repetition_rules(tree)
    reduce_array_set(tree)
    reduce_program_set(tree)
    reduce_string(tree)
  end

  def remove_alternation_rules(tree)
    tree.reduce_roots(:alternation)
  end

  def remove_option_rules(tree)
    tree.reduce_roots(:option)
  end

  def remove_repetition_rules(tree)
    tree.remove_roots(:repetition)
  end

  def reduce_array_set(tree)
    tree.remove_roots(:element_list)
    tree.remove_roots(:element_more)
    tree.remove_roots(:element_more_once)
    tree.delete_nodes(:element_divider)
    tree.delete_nodes(:array_start)
    tree.delete_nodes(:array_end)
    remove_nullable_child(tree, :array)
  end

  def remove_nullable_child(tree, tree_match)
    tree.find_all{|i| i === tree_match}
      .select{|i| i.has_child? :nullable}
      .select{|i| i.degree > 1}
      .map{|i| i.children}
      .each do |cl|
      cl.each {|t| t === :nullable ? t.delete_node(:nullable) : nil}
    end
    tree
  end

  def reduce_program_set(tree)
    tree.delete_nodes(:declaration_list)
    tree.delete_nodes(:declaration_more_once)
    tree.delete_nodes(:declaration_divider)
    tree.delete_nodes(:program_start)
    tree.delete_nodes(:program_end)
    remove_nullable_child(tree, :program)
  end

  def reduce_string(tree)
    tree.delete_nodes(:string_delimiter)
    remove_nullable_child(tree, :string)
  end
end
