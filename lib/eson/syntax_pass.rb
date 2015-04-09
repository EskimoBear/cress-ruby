require_relative './formal_languages.rb'

module Eson::SyntaxPass

  extend Eson::FormalLanguages
  extend self

  ParseError = Class.new(StandardError)

  #@param token_seq [TokenSeq]  
  #@return [AbstractSyntaxTree]
  def build_tree(token_seq)
    rules = syntax_pass_lang.rule_seq
    syntax_pass_lang.top_rule.parse(token_seq, rules)
  end
end
