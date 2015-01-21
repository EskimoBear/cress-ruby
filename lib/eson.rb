require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/language'
require_relative 'eson/compile_pass'

module Eson

  include Vert
  extend self

  SyntaxError = Class.new(StandardError)

  EMPTY_PROGRAM = "empty_program"
  MALFORMED_PROGRAM = "Program is malformed"
  MALFORMED_PROGRAM_RGX = /Program is malformed/

  def compile(eson_program)
    if validate_json?(eson_program)
      tokenizer_output = Tokenizer.tokenize_program(eson_program)
      verified_special_forms = CompilePass.verify_special_forms(tokenizer_output.first)
      variables = verified_special_forms.tokenize_variable_identifiers
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
