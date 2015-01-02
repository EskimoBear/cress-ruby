require 'vert'
require 'oj'

module Eson

  include Vert
  extend self

  def read(eson_string)
    validate_json(eson_string)
    eson_json = Oj.load(eson_string)
    Eson::Parser.generate_ast(eson_json)
  end

  module Parser

    extend self
    def generate_ast(eson_json)
    end
  end
end
