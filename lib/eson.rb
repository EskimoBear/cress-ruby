require 'vert'
require_relative 'eson/tokenizer'

module Eson

  include Vert
  extend self

  def compile(eson_program)
    if validate_json?(eson_program)
      Tokenizer.tokenize_program(eson_program)
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
