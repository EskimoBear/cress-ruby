module AST

  def convert_to_ast(tree)
    remove_alternation_rules(tree)
  end

  def remove_alternation_rules(tree)
    tree.reduce_roots(:alternation)
    tree
  end
end
