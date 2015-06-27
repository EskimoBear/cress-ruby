require 'vert'
require_relative 'dote/token_pass'
require_relative 'dote/syntax_pass'
require_relative 'dote/code_gen'

module Dote

  include Vert
  extend self

  SyntaxError = Class.new(StandardError)

  LANG = Dote::DoteGrammars.compile_grammar
  EMPTY_PROGRAM = "empty_program"
  MALFORMED_PROGRAM = "Program is malformed"

  #@param program [String] string representation of the program
  #@param grammar [Struct] grammar to process program
  #@return [nil, Parser::ParseTree] parse tree for the program
  #@raise SyntaxError, when program is malformed JSON
  def compile(program, grammar=LANG)
    if validate_json?(program)
      token_sequence = TokenPass.tokenize_program(program, grammar)
                       .verify_special_forms
      tree = SyntaxPass.build_tree(token_sequence, grammar)
    else
      validation_pass(program)
    end
  end

  def validation_pass(program)
    options = {:custom_errors =>
               {:empty_json_object => EMPTY_PROGRAM,
                :malformed_json => MALFORMED_PROGRAM}}
    case validate_json(program, options)
    when EMPTY_PROGRAM
      return nil
    when Regexp.new(MALFORMED_PROGRAM)
      raise SyntaxError, validate_json(program, options)
    end
  end

  def semantic_pass(tree, grammar)
    store = grammar.build_store(tree)
    {:env =>{:store => store}}
  end
end
