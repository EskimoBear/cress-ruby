module Eson

  #Class contains tree operations for stuct based trees that
  #conform to the following properties. 
  #Properties of the tree A, abstract syntax tree 
  # Prop : an eson token/terminal is added to A as a leaf
  #      : A leaf node has lexeme and type properties
  #      : A production rule is added to A as a tree
  #      : A tree has type, first_set and follow_set properties
  #      : A node is a production rule each sub-tree belongs to a
  #          valid token sequence or the rule.
  #      : Sub-trees are ordered by insertion order, earliest insertion
  #          is leftmost
  class AbstractSyntaxTree
  end
end
