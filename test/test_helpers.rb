require 'pp'
require_relative '../lib/dote'

module TestHelpers

  DEFAULT_GRAMMAR = Dote::DoteGrammars.compile_grammar
  extend self

  def get_sample_rules
    Dote::RuleSeq.new
      .make_terminal_rule(:terminal, /rule/)
      .make_alternation_rule(:nonterminal, [:terminal])
  end

  def get_sample_terminal
    get_sample_rules.get_rule(:terminal)
  end

  def get_sample_production
    get_sample_rules.get_rule(:nonterminal)
  end
  
  def get_valid_eson
    load_test_inputs('valid')
  end

  def get_unknown_special_form_program
    load_test_inputs('unknown_special_form')
  end

  def get_tokenizer_sample_program
    load_test_inputs('tokenizer_sample')
  end

  def get_empty_program
    "{}"
  end

  def get_malformed_program
    "{\"malformed\": (}"
  end

  def get_tokens(grammar=DEFAULT_GRAMMAR)
    Dote::TokenPass.tokenize_program(
      get_tokenizer_sample_program,
      grammar)
      .verify_special_forms
  end

  def get_token_sequence(program=get_tokenizer_sample_program,
                         grammar=DEFAULT_GRAMMAR)
    Dote::TokenPass
      .tokenize_program(
        program,
        grammar)
      .verify_special_forms
  end

  def get_parse_tree(token_sequence=get_token_sequence,
              grammar=DEFAULT_GRAMMAR)
    Dote::SyntaxPass.build_tree(token_sequence, grammar)
  end

  def get_ast(tree=get_parse_tree,
              grammar=DEFAULT_GRAMMAR)
    Dote::SyntaxPass.build_ast(tree, grammar)
  end

  def get_semantic_eval(tree=get_parse_tree,
                        grammar=DEFAULT_GRAMMAR)
    Dote.semantic_pass(tree, grammar)
  end

  def get_code(tree=get_parse_tree,
               grammar=DEFAULT_GRAMMAR,
               path=get_code_gen_dir,
               file_name="code.dt")
    Dote::CodeGen.make_file(tree, grammar, path, file_name)
  end

  def get_code_gen_dir
    test_dir = File.expand_path(File.dirname(__FILE__))
    path = File.join(test_dir, "code_gen_tmp")
    unless File.directory?(path)
      FileUtils.mkdir(path)
    end
    path
  end
  
  private

  def get_test_input_path(name)
    file = File.join('../../test/dote_inputs', "#{name}.dt")
    File.expand_path(file, __FILE__)
  end

  def load_test_inputs(name)
    File.open(get_test_input_path(name)).read
  end
end
