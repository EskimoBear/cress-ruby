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

    JsonSymbol = Struct.new "JsonSymbol", :value, :name
    Token = Struct.new "Token", :value, :name
    
    #Converts an eson program into a sequence of eson tokens
    #@param eson_program [String] string provided to Eson#read
    #@return [Array<Array>] A pair of token sequence and the input sequence
    #@eskimobear.specification
    # Eson token set, ET is a set of the eson terminal symbols defined below
    # ---EBNF
    # program_start = "{";
    # program_end = "}";
    # end_of_file = EOF;
    # comma = ",";
    # colon = ":";
    # proc_prefix = "&";
    # variable_prefix = "$";
    # key_word = {JSON_char};
    # word = {JSON_char}; 
    # other_chars = {JSON_char};
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
      json_hash = Oj.load(eson_program)
      json_symbol_sequence = get_json_symbol_sequence(json_hash)
      puts tokenize_json_symbols(json_symbol_sequence)
    end

    def string_to_char_sequence(string)
      seq = Array.new
      string.each_char {|c| seq << c}
      seq
    end
    
    def get_json_symbol_sequence(hash)
      Array.new.push(JsonSymbol.new("{","object_start"))
        .push(members_to_json_symbols(hash))
        .push(JsonSymbol.new("}","object_end"))
        .flatten
    end

    def members_to_json_symbols(json_pairs)
      seq = Array.new << pair_to_json_symbols(json_pairs.first)
      rest = json_pairs.drop(1)
      rest.each_with_object(seq) do |i, seq|
        seq.push(JsonSymbol.new(",", "comma"))
          .push(pair_to_json_symbols(i))
      end
    end

    def pair_to_json_symbols(json_pair)
      value = if json_pair[1].is_a? Hash
                get_json_symbol_sequence(json_pair[1])
              else
                JsonSymbol.new(json_pair[1], "JSON_value")
              end
      Array.new.push(JsonSymbol.new(json_pair.first, "JSON_key"))
        .push(JsonSymbol.new(":", "colon"))
        .push(value)
        .flatten
    end

    def symbol_length(json_symbol)
      json_symbol.value.length
    end
    
    def tokenize_json_symbols(symbol_seq)
      symbol_seq.each_with_object(Array.new) do |symbol, seq|
        case symbol.name
        when "object_start"
          seq.push(Token.new("{", "program_start"))
        when "object_end"
          seq.push(Token.new("}", "program_end"))
        when "colon"
          seq.push(Token.new(":", "colon"))
        when "comma"
          seq.push(Token.new(",", "comma"))
        when "JSON_key"
          tokenize_json_key(symbol.value, seq)
        when "JSON_value"
          tokenize_json_value(symbol.value, seq)
        end
      end
    end

    def tokenize_json_key(json_key, seq)
      if begins_with_proc_prefix?(json_key)
        seq.push(Token.new("&", "proc_prefix"))
        tokenize_words_and_special_forms(get_prefixed_string(json_key), seq)
      else
        seq.push(Token.new(json_key, "key_word"))
      end
    end

    def begins_with_proc_prefix?(string)
      string[0] == "&"
    end
    
    def get_prefixed_string(string)
      string[1..-1]     
    end

    def tokenize_json_value(json_value, seq)
      if json_value.is_a? TrueClass
        seq.push(Token.new(json_value, "true"))
      elsif json_value.is_a? Numeric
        seq.push(Token.new(json_value, "number"))
      elsif json_value.is_a? Array
        seq.push(Token.new(json_value, "array"))
      elsif json_value.is_a? FalseClass
        seq.push(Token.new(json_value, "false"))
      elsif json_value.nil?
        seq.push(Token.new(json_value, "null"))
      elsif json_value.is_a? String
        tokenize_json_string(json_value, seq)
      end
    end

    def tokenize_json_string(json_string, seq)
      if json_string.empty?
        seq
      elsif match_leading_whitespace_or_variable_prefix?(json_string)
        tokenize_prefix(json_string, seq)
        tokenize_json_string(get_prefixed_string(json_string), seq)
      elsif match_other_chars?(json_string)
        other_chars, rest = get_other_chars_and_string(json_string)
        seq.push(Token.new(other_chars, "other_chars"))
        tokenize_json_string(rest, seq)
      else
        next_word, rest = get_next_word_and_string(json_string)
        tokenize_words_and_special_forms(next_word, seq)
        tokenize_json_string(rest, seq)
      end
    end

    def match_leading_whitespace_or_variable_prefix?(string)
      string.match(/\A(\$|\s)/).to_s == "" ? false : true   
    end

    def tokenize_prefix(json_string, seq)
      case next_char(json_string)
     when "$"
        seq.push(Token.new("$", "variable_prefix"))
      when " "
        seq.push(Token.new(" ", "whitespace"))
      end
    end

    def match_other_chars?(string)
      string.match(/\A[\W]*/).to_s == "" ? false : true
    end

    def get_other_chars_and_string(string)
      other_chars = string.match(/\A[\W]*/)
      rest_start_index = other_chars.end(0)
      [other_chars.to_s, string[rest_start_index..-1]]
    end

    def next_char(string)
      string[0]
    end

    def get_next_word_and_string(string)
      next_word = string.match(/[a-zA-Z\-_.\d]*/)
      rest_start_index = next_word.end(0)
      [next_word.to_s, string[rest_start_index..-1]]
    end
    
    def tokenize_words_and_special_forms(json_string, seq)
      special_form = match_special_form(json_string)
      case special_form
      when "doc"
        seq.push(Token.new(json_string, "doc"))
      when "let"
        seq.push(Token.new(json_string, "let"))
      when "ref"
        seq.push(Token.new(json_string, "ref")) 
      when ""
        seq.push(Token.new(json_string, "word"))
      end      
    end

    def match_special_form(string)
      string.match(/\A(let|ref|doc)/).to_s
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
  #call = procedure, colon, array | null | single;
  #
  #procedure = proc_prefix, special-form; 
  #proc_prefix = "&";
  #special-form = let | ref | doc;
  #let = "let";
  #ref = "ref";
  #doc = "doc";
  #colon = ":";
  #
  #value = variable_identifier | string | single | document | number |
  #        array | true | false | null;
  #
  #(*a variable_identifier is a string that can be dereferenced to a value held 
  #  in the value store*)
  #variable_identifier = variable_prefix, word;
  #variable_prefix = "$";
  #
  #string = [whitespace | variable_prefix], [word | other_chars],
  #         {[whitespace | variable_prefix], [word | other_chars]};
  #whitespace = " ";
  #word = {char}; (*letters, numbers, '-', '_', '.'*)
  #other_chars = {char}; (*characters excluding those found
  #   in variable_prefix, word and whitespace*)
  #
  #(*an attribute performs simultaneous variable and
  # value creation*)
  #attribute = key_word, colon, value;
  #key_word = {char} (*all characters excluding proc_prefix*)
  #
  #(*a single is a program allowing
  # procedure application and substitution*)
  #single = program_start, call, program_end;
  #
  #prefix = proc_prefix | variable_prefix;
  #
  #(*a document is a program that contains only attributes*)
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
