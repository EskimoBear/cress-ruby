require 'vert'
require_relative 'eson/tokenizer'
require_relative 'eson/parser'

module Eson

  include Vert
  extend self
  
  def read(eson_program)
    validate_json(eson_program)
    Tokenizer.tokenize_program(eson_program)
  end
  
end
