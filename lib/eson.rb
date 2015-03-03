require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/formal_languages'
require_relative 'eson/error_pass'

module Eson

  include Vert
  extend self

  SyntaxError = Class.new(StandardError)

  EMPTY_PROGRAM = "empty_program"
  MALFORMED_PROGRAM = "Program is malformed"
  MALFORMED_PROGRAM_RGX = /Program is malformed/

  def compile(eson_program)
    if validate_json?(eson_program)
      tokenizer_output = Tokenizer.tokenize_program(eson_program).first
                         .add_line_numbers
      ErrorPass.verify_special_forms(tokenizer_output)
        .tokenize_variable_identifiers
        .tokenize_special_forms
        .tokenize_proc_identifiers
        .tokenize_word_forms
        .label_sub_strings
        .insert_string_delimiters
    else
      validation_pass(eson_program)
    end
  end

  def validation_pass(eson_program)
    options = {:custom_errors =>
               {:empty_json_object => EMPTY_PROGRAM,
                :malformed_json => MALFORMED_PROGRAM}}
    case validate_json(eson_program, options)
    when EMPTY_PROGRAM
      return nil
    when MALFORMED_PROGRAM_RGX
      raise SyntaxError, validate_json(eson_program, options)
    end
  end
  
end
