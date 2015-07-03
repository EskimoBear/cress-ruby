require 'vert'
require_relative 'dote/token_pass'

module Dote

  include Vert
  extend self

  SyntaxError = Class.new(StandardError)

  LANG = Dote::DoteGrammars.compile_grammar
  EMPTY_PROGRAM = "empty_program"
  MALFORMED_PROGRAM = "Program is malformed"

  # @param program [String] string representation of the program
  # @param grammar [ITokenizer, IParser]
  # @return [nil, Hash] the environment for the executed the program
  # @raise SyntaxError, when program is malformed JSON
  def compile(program, grammar=LANG)
    if validate_json?(program)
      token_sequence = TokenPass.tokenize_program(program, grammar)
                       .verify_special_forms(grammar)
      tree = build_tree(token_sequence, grammar)
      operational_semantics(tree, grammar)
    else
      validation_pass(program)
    end
  end

  # @param program [String] string representation of the program
  # @param grammar [ITokenizer, IParser]
  # @return [nil, Parser::ParseTree] parse tree for the program
  # @raise SyntaxError, when program is malformed JSON
  def source_to_tree(program, grammar=LANG)
    if validate_json?(program)
      token_sequence = TokenPass.tokenize_program(program, grammar)
                       .verify_special_forms(grammar)
      tree = build_tree(token_sequence, grammar)
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

  # @param token_seq [TokenSeq]
  # @param grammar [IParser]
  # @return [AbstractSyntaxTree] ParseTree for token_seq
  def build_tree(token_seq, grammar)
    parse_tree = grammar.parse_tokens(token_seq)
    grammar.eval_tree_attributes(parse_tree)
  end

  # @param tree [Parser::ParseTree]
  # @param grammar [RuleSeq]
  # @return [Hash] the environment of the executed program
  def operational_semantics(tree, grammar)
    ast = grammar.convert_to_ast(tree)
    store = grammar.build_store(ast)
    {store: store, tree: ast}
  end

  # Generate object code for env
  # @param env [Hash]
  # @param grammar [ICode]
  # @param path [String]
  # @param file_name [String]
  # @return [Void]
  def build_object_code(env, grammar, path, file_name)
    grammar.generate_source(env[:tree], path, file_name)
  end
end
