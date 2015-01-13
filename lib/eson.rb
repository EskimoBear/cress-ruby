require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/parser'

module Eson

  include Vert
  extend self

  def compile(eson_program)
    if validation_pass(eson_program) == :empty_program
      return nil
    end
    Tokenizer.tokenize_program(eson_program)
  end

  def validation_pass(eson_program)
    options = {:custom_errors =>
               {:empty_json_object => :empty_program}}
    validate_json(eson_program, options).intern
  end
  
end
