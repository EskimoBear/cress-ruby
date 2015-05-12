require_relative './eson_grammars.rb'

module Eson::SyntaxPass

  extend Eson::EsonGrammars
  extend self

  ParseError = Class.new(StandardError)

  #Produce AbstractSyntaxTree for eson program
  #@param token_seq [TokenSeq]  
  #@return [AbstractSyntaxTree]
  def build_tree(token_seq)
    rules = tokenizer_lang.copy_rules
    tokenizer_lang.top_rule.parse(token_seq, rules)[:tree]
  end
end
