require_relative 'rule_seq.rb'
$LOAD_PATH.unshift(File.expand_path("../../dote/grammars", __FILE__))
require 'tokenizer_cfg.rb'
require 'display_fmt.rb'
require 'dote_fmt.rb'
require 'ast.rb'
require 'variable_store'

module Dote
  module DoteGrammars

    extend self

    RuleSeq =  Dote::RuleSeq
    Rule = Dote::Rule

    alias_method :compile_grammar, :ast
  end
end
