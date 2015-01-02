require 'vert'
require 'oj'

module Eson

  include Vert
  extend self
  
  def read(eson_string)
    validate_json(eson_string)
    json_tokens = Oj.load(eson_string)
    Eson::Parser.generate_ast(json_tokens)
  end

  #The following EBNF rules describe the eson grammar. All terminal
  #symbols that begin with 'JSON_' reference those terminal symbols
  #defined in the JSON grammar.
  #
  #doc = '{',statement, {statement}, '}', EOF;
  #statement = line, NEWLINE;
  #line = weak-single | record;
  #special-forms = "ref" | "def" | "doc";
  #symbol = [special-forms];
  #weak-single = "&", symbol, :, JSON_array | JSON_null | weak-single;
  #single = '{' , weak-single, '}';
  #record = JSON_pair;  
  module Parser

    extend self
  
    def generate_ast(json_tokens)
    end
  end
end
