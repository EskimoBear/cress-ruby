require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/language'
require_relative 'eson/pass'

module Eson

  include Vert
  extend self

  def compile(eson_program)
    if validate_json?(eson_program)
      tokenizer_output = Tokenizer.tokenize_program(eson_program)
      Pass.verify_special_forms(tokenizer_output.first, tokenizer_output[2])
    else
      validation_pass(eson_program)
    end
  end

  def validation_pass(eson_program)
    options = {:custom_errors =>
               {:empty_json_object => :empty_program}}
    case validate_json(eson_program, options).intern
    when :empty_program
      return nil
    end
  end
  
end
