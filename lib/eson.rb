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
  #program = '{', {declaration}, '}' | single | document, EOF;
  #
  #declaration = eson_pair, ',';
  #eson_pair = call | let | attribute | eson_pair_json;
  #
  #(*a call is a declaration performing procedure application without
  #  direct substitution*)
  #call = procedure, :, JSON_array | JSON_null | single;
  #procedure = "&", special-form; 
  #special-form = "let" | "ref" | "doc";
  #
  #(*a single is a type of JSON object allowing
  # procedure application and substitution*)
  #single = '{' , call, '}';
  #
  #(*the let call performs variable creation *)
  #let = "&", "let", :, '[', {JSON_string, ','}, ']';
  #
  #(*an attribute is a declaration that evaluates to a JSON_pair performing
  # simultaneous variable and value creation*)
  #attribute = JSON_string, :, eson_value;
  #eson_value = single | identifier, [JSON_string] | JSON_value;
  #
  #(*an identifier is a JSON string that can be dereferenced to a value held 
  #  in the value store*)
  #identifier = "$", JSON_string;
  #
  #(*eson_pair_json describes the eson_pair in terms of it's JSON counterpart*)
  #eson_pair_json = eson_string, :, eson_value;
  #eson_string = prefix, JSON_string | procedure | identifier, [JSON_string] ;
  #prefix = ["&", "$"];
  #
  #(*a document is the equivalent to the program's internal value store*)
  #document = '{', {attribute}, '}' | JSON_object, EOF;
  #
  #JSON_object = '{', {statement}, '}';
  #statement = JSON_pair, ',';
  #JSON_pair = JSON_value, :, JSON_string;
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
