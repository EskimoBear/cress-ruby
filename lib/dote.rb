require 'vert'
require_relative 'dote/token_pass'

module Dote

  include Vert
  extend self

  SyntaxError = Class.new(StandardError)

  LANG = Dote::DoteGrammars.compile_grammar
  EMPTY_PROGRAM = "empty_program"
  MALFORMED_PROGRAM = "Program is malformed"

  # Generate an object code file for the program provided
  # @param program [String] string representation of the program
  # @param grammar [IObjectCode]
  # @param output_path [String]
  # @return [nil]
  def compile(program, grammar, output_path)
    env = source_to_env(program, grammar)
    unless env.nil?
      build_object_code(env, grammar, output_path)
    end
  end

  # @param program [String] string representation of the program
  # @param grammar [ISemantics]
  # @return [nil, Hash] the environment for the executed program
  # @raise SyntaxError, when program is malformed JSON
  def source_to_env(program, grammar=LANG)
    if validate_json?(program)
      token_sequence = TokenPass.tokenize_program(program, grammar)
                       .verify_special_forms(grammar)
      tree = build_tree(token_sequence, grammar)
      operational_semantics(tree, grammar)
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
  # @return [AbstractSyntaxTree] ParseTree for token_seq with s-attributes
  # and i-attributes
  def build_tree(token_seq, grammar)
    parse_tree = grammar.parse_tokens(token_seq)
    grammar.eval_tree_attributes(parse_tree)
  end

  # @param tree [Parser::ParseTree]
  # @param grammar [ISemantics]
  # @return [Hash] the environment of the executed program
  def operational_semantics(tree, grammar)
    ast = grammar.convert_to_ast(tree)
    store = grammar.build_store(ast)
    {store: store, tree: ast}
  end

  # Generate object code for env
  # @param env [Hash]
  # @param grammar [IObjectCode]
  # @param output_path [String]
  # @return [nil]
  def build_object_code(env, grammar, output_path)
    code = grammar.generate_code(env)
    grammar.make_file(code, output_path)
    nil
  end
end
