require_relative './eson_grammars.rb'

module Eson::SyntaxPass

  extend Eson::EsonGrammars
  extend self

  ParseError = Class.new(StandardError)

  #Produce AbstractSyntaxTree for eson program
  #@param token_seq [TokenSeq]  
  #@return [AbstractSyntaxTree]
  def build_tree(token_seq, grammar)
    ast = grammar.top_rule.parse(token_seq, grammar)[:tree]
    grammar.eval_tree_attributes(ast)
  end

  def build_ast(tree, grammar)
    grammar.convert_to_ast(tree)
  end
end
