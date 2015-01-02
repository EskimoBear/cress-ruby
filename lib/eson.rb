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
  #document = '{', {declaration}, '}', EOF;
  #declaration = eson_pair, ',';
  #eson_pair = prefix , JSON_string, :, eson_value;
  #prefix = ["&", "$"];
  #eson_value = JSON_value | single;
  #(*a single is a type of JSON object allowing
  # evaluation and substitution*)
  #single = '{' , weak-single, '}';
  #(*a weak-single is a type of eson_pair allowing
  # evaluation without direct substitution*)
  #weak-single = "&", symbol, :, JSON_array | JSON_null | single;
  #symbol = special-form; (*a subset of JSON_string*)
  #special-form = "ref" | "def" | "doc";
  #(*a record is a type of eson_pair which defines a compound data type*)
  #record = JSON_string, :, document;
  #(*an attribute is an eson_pair that evaluates to a JSON_pair*)
  #attribute = JSON_string :, single;
  #(*an identifier is an eson_pair that binds an eson_value to the
  #  JSON_string prefixed with a $*)
  #identifier = "$", JSON_string, :, eson_value;

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
