require 'vert'
require 'oj'

module Eson

  include Vert
  extend self
  
  def read(eson_string)
    validate_json(eson_string)
    Eson::Parser.generate_ast(eson_string)
  end

  #The following EBNF rules describe the eson grammar. All terminal
  #symbols that begin with 'JSON_' reference those terminal symbols
  #defined in the JSON grammar.
  #
  #doc = '{', declaration, {declaration}, '}', EOF;
  #declaration = line, NEWLINE;
  #line = weak-single | record;
  #special-forms = "ref" | "def" | "doc";
  #symbol = [special-forms];
  #weak-single = "&", symbol, :, JSON_array | JSON_null | weak-single;
  #single = '{' , weak-single, '}';
  #record = JSON_pair;  
  module Parser

    extend self
  
    def generate_ast(doc)
      declarations = get_declarations(doc)
    end

    #Returns an array of declarations. 
    #@param doc [String] the eson document
    #@return [Array] Each declaration is an array pair of the
    #                form [JSON_name, JSON_value].
    def get_declarations(doc)
      hash = Oj.load(doc)
      hash.each_with_object([]) {|i, array| array << i}
    end
  end
end
