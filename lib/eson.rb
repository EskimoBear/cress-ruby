require 'vert'
require 'oj'

module Eson

  include Vert
  extend self
  
  def read(eson_program)
    validate_json(eson_program)
    Tokenizer.tokenize_program(eson_program)
  end

  module Tokenizer

    extend self
    
    #Converts an eson program into a sequence of eson tokens
    #@param eson_program [String] the eson program string provided to Eson#read
    #@return [Array<Array>] Returns a sequence of the token sequence and the input sequence
    #@eskimobear.specification
    # Eson token set, ET is a set of the eson terminal symbols defined below
    # ---EBNF
    # program_start = "{";
    # program_end = "}";
    # end_of_file = EOF;
    # array_start = "[";
    # array_end = "]";
    # comma = ",";
    # colon = ":";
    # proc_prefix = "&";
    # variable_prefix = "$";
    # string = {char};
    # char = JSON_char;
    # whitespace = " ";
    # number = JSON_number;
    # true = JSON_true;
    # false = JSON_false;
    # null = JSON_null;
    # let = "let";
    # ref = "ref";
    # doc = "doc";
    # ---EBNF
    # Eson token, et is a member of ET
    # Input program, p, a valid JSON string 
    # Input sequence, P, a sequence of characters in p
    # Token sequence, T
    #
    # Init : length(P) > 0
    #        length(T) = 0
    # Next : length(P') = length(P) - value_length(et)
    #        length(T') = length(T) + 1
    #
    # Append program_start token onto T
    # Convert P to a sequence of JSON pairs, 2-tuple arrays of keys and values
    # Replace each pair with a 3-tuple including the colon token as the middle element
    # Inspect each key and value in the pair and split into tokens present in ET
    #   Label each token with it's terminal symbol
    #   Replace the key or value with an array of these tokens
    # Append the first 3-tuple to T and then append a comma token
    # Repeat until the last 3-tuple is reached and then append the last 3-tuple to T
    # Append program_end token to T 
    # Flatten T and output
    def tokenize_program(eson_program)
    end
  end

  #Specification - Parse tokens into a abstract syntax tree
  #
  #The following EBNF rules describe the eson grammar. 
  #---EBNF
  #program = program_start, declaration, program_end, [end_of_file];
  #
  #program_start = "{";
  #program_end = "}";
  #end_of_file = EOF;
  #
  #declaration = pair, {comma, pair};
  #pair = call | let_call | attribute;
  #comma = ",";
  #
  #(*a call is a declaration performing procedure application without
  #  direct substitution*)
  #call = procedure, colon, array | null;
  #
  #procedure = proc_prefix, special-form; 
  #proc_prefix = "&";
  #special-form = let | ref | doc;
  #let = "let";
  #ref = "ref";
  #doc = "doc";
  #colon = ":";
  #
  #array = array_start, {element}, array_end;
  #
  #array_start = '[';
  #array_end = ']';
  #element = value, {comma, value};
  #value = variable | program | single | document | string | number |
  #        array | true | false | null;
  #
  #(*a variable is a string that can be dereferenced to a value held 
  #  in the value store*)
  #variable = variable_prefix, {char}, whitespace; 
  #whitespace = " ";
  #variable_prefix = "$";
  #
  #(*the let call performs variable creation *)
  #let_call = proc_prefix, let, colon, array_start, let_input,
  #           {comma, let_input}, array_end;
  #let_input = string | variable;
  #
  #(*an attribute performs simultaneous variable and
  # value creation*)
  #attribute = string, colon , value;
  #
  #(*a single is a program allowing
  # procedure application and substitution*)
  #single = program_start, call, program_end;
  #
  #prefix = proc_prefix | variable_prefix;
  #
  #(*a document is a program that is equivalent to the it's internal value store*)
  #document = program_start, {attribute, [comma, attribute]}, program_end, end_of_file;
  #---EBNF
  module Parser

    extend self

    #Append declaration type to make syntax tuple [declaration, type]
    #
    #Returns an array of syntax structs [[declaration, type]]
    #@param program [String] the eson program
    #@return [Array] Each syntax tuple is an array pair of the
    #                form [declarations, type]
    def generate_ast(program)
      declarations = get_declarations(program)
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
