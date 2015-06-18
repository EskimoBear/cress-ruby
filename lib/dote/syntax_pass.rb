require_relative './dote_grammars.rb'

module Dote::SyntaxPass

  extend Dote::DoteGrammars
  extend self

  ParseError = Class.new(StandardError)

  #Produce AbstractSyntaxTree for eson program
  #@param token_seq [TokenSeq]  
  #@return [AbstractSyntaxTree]
  def build_tree(token_seq, grammar)
    parse_tree = grammar.top_rule.parse(token_seq, grammar)[:tree]
    grammar.eval_tree_attributes(parse_tree)
  end

  def build_ast(tree, grammar)
    grammar.convert_to_ast(tree)
  end
end
