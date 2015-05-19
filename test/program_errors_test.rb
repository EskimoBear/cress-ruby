require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/eson_grammars'
require_relative '../lib/eson/program_errors'
require_relative './test_helpers'

describe "ProgramErrors" do

  include TestHelpers
  
  subject {ProgramErrors}
  
  it "#parse_terminal_error_message" do
    invalid_tokens = get_token_sequence
                     .delete_if{|i| i.name == :array_end}
    proc {get_ast(invalid_tokens)}
      .must_raise ProgramErrors::InvalidSequenceParsed
  end
  it "#exhausted_tokens_error_message" do
    invalid_tokens = get_token_sequence
                     .take_while{|i| i.name != :array_end}
    proc {get_ast(invalid_tokens)}
      .must_raise ProgramErrors::InvalidSequenceParsed
  end
  it "#unknown_special_form_error_message" do
    proc { get_token_sequence(
             Eson::EsonGrammars.tokenizer_lang,
             get_unknown_special_form_program)}
      .must_raise ProgramErrors::UnknownSpecialForm
  end
end
