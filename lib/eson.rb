# coding: utf-8
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
    #@param eson_program [String] string provided to Eson#read
    #@return [Array<Array>] A pair of token sequence and the input sequence
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
    # Eson token, et is a sequence of characters existing in ET
    # label(et) maps the character sequence to the name of the matching
    #   eson terminal symbol
    # Input program, p, a valid JSON string 
    # Input sequence, P, a sequence of characters in p
    # Token sequence, T
    #
    # Init : length(P) > 0
    #        length(T) = 0
    # Next : et = P - 'P ∧ T' = T + label(et)
    #
    # Convert p to JSON_P a sequence of JSON symbols - [object_start, object_end,
    # comma, colon, JSON_key, JSON_value]
    # For each symbol in JSON_P
    #   remove the first n chars from P, where n = symbol length
    #   inspect each symbol
    #    split into sequence of et's
    #    label each et with it's terminal symbol
    #    append et to T
    def tokenize_program(eson_program)
      program_sequence = string_to_char_sequence(eson_program)
      token_sequence = Array.new
      json_p = to_json_symbols(eson_program)
      tokenize_json_symbols(json_p)
    end
    
    def to_json_symbols(eson_program)
      json_hash = Oj.load(eson_program)
      json_symbol = Struct.new "JSONsymbol", :value, :name
      seq = Array.new << json_symbol.new("{","object_start")
      seq << members_to_json_symbols(json_hash, json_symbol)
      seq << json_symbol.new("}","object_end")
      seq.flatten
    end

    def members_to_json_symbols(json_pairs, json_symbol)
      seq = Array.new << pair_to_json_symbols(json_pairs.first, json_symbol)
      rest = json_pairs.drop(1)
      comma = json_symbol.new(",", "comma")
      rest.each_with_object(seq) do |i, seq|
        seq << comma
        seq << pair_to_json_symbols(i, json_symbol)
      end
    end

    def pair_to_json_symbols(json_pair, json_symbol)
      colon = json_symbol.new(":", "colon")
      Array.new << json_symbol.new(json_pair.first, "JSON_key") << colon << json_symbol.new(json_pair[1], "JSON_value")
    end

    def symbol_length(json_symbol)
      json_symbol.value.length
    end
    
    def string_to_char_sequence(string)
      seq = Array.new
      string.each_char {|c| seq << c}
      seq
    end

    def tokenize_json_symbols(sequence)
      seq = Array.new
      token = Struct.new "Token", :value, :name
      sequence.map do |i|
        case i.name
        when "object_start"
          seq << token.new("{","program_start")
        when "object_end"
          seq << token.new("}","program_end")
        when "colon"
        when "comma"
        when "JSON_key"
          tokenize_json_key(i.value, seq)
        when "JSON_value"
          tokenize_json_value(i.value, seq)
        end
      end
      puts seq
    end

    def tokenize_json_key(json_key, seq)
      token = Struct.new "Token", :value, :name
      eson_prefix = get_eson_prefix(json_key)
      case eson_prefix
      when "$"
        seq << token.new(eson_prefix, "variable_prefix")
        seq << token.new(get_prefixed_string(json_key), "string")
      when "&"
        seq << token.new(eson_prefix, "proc_prefix")
        seq << token.new(get_prefixed_string(json_key), "string")
      when ""
        seq << token.new(json_key, "string")
      end
    end
    
    def get_eson_prefix(string)
      string.match(/\A\$|&/).to_s
    end

    def get_prefixed_string(string)
       string.match(/\A\$|&/).post_match     
    end

    def tokenize_json_value(json_value, seq)
      token = Struct.new "Token", :value, :name
      if json_value.is_a? TrueClass
        seq << token.new(json_value, "true")
      elsif json_value.is_a? FalseClass
        seq << token.new(json_value, "false")
      elsif json_value.is_a? Numeric
        seq << token.new(json_value, "number")
      elsif json_value.nil?
        seq << token.new(json_value, "null")
      elsif json_value.is_a? String
        seq << token.new(json_value, "string")
      end
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
  #pair = call | attribute;
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
  #variable = variable_prefix, word, whitespace;
  #word = string;
  #whitespace = " ";
  #variable_prefix = "$";
  #
  #(*an attribute performs simultaneous variable and
  # value creation*)
  #attribute = string, colon, value;
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

  end
end
