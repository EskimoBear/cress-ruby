# coding: utf-8
require 'oj'

module Eson

  module Tokenizer

    extend self

    JsonSymbol = Struct.new "JsonSymbol", :value, :name
    Token = Struct.new "Token", :value, :name
    
    #Converts an eson program into a sequence of eson tokens
    #@param eson_program [String] string provided to Eson#read
    #@return [Array<Array>] A pair of token sequence and the input char sequence
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
      program_char_seq = get_program_char_sequence(eson_program)
      program_json_hash = Oj.load(eson_program)
      json_symbol_seq = get_json_symbol_sequence(program_json_hash)
      token_seq = tokenize_json_symbols(json_symbol_seq)
      #puts token_seq
      [token_seq, program_char_seq]
    end

    private

    def get_program_char_sequence(string)
      seq = Array.new
      string.each_char {|c| seq << c}
      seq
    end
    
    def get_json_symbol_sequence(hash)
      Array.new.push(JsonSymbol.new(:"{",:object_start))
        .push(members_to_json_symbols(hash))
        .push(JsonSymbol.new(:"}",:object_end))
        .flatten
    end

    def members_to_json_symbols(json_pairs)
      seq = Array.new << pair_to_json_symbols(json_pairs.first)
      rest = json_pairs.drop(1)
      rest.each_with_object(seq) do |i, seq|
        seq.push(JsonSymbol.new(:",", :comma))
          .push(pair_to_json_symbols(i))
      end
    end

    def pair_to_json_symbols(json_pair)
      value = if json_pair[1].is_a? Hash
                get_json_symbol_sequence(json_pair[1])
              else
                JsonSymbol.new(json_pair[1], :JSON_value)
              end
      Array.new.push(JsonSymbol.new(json_pair.first, :JSON_key))
        .push(JsonSymbol.new(:":", :colon))
        .push(value)
        .flatten
    end

    def symbol_length(json_symbol)
      json_symbol.value.size
    end
    
    def tokenize_json_symbols(symbol_seq)
      symbol_seq.each_with_object(Array.new) do |symbol, seq|
        case symbol.name
        when :object_start
          seq.push(Token.new(:"{", :program_start))
        when :object_end
          seq.push(Token.new(:"}", :program_end))
        when :colon
          seq.push(Token.new(:":", :colon))
        when :comma
          seq.push(Token.new(:",", :comma))
        when :JSON_key
          tokenize_json_key(symbol.value, seq)
        when :JSON_value
          tokenize_json_value(symbol.value, seq)
        end
      end
    end

    def tokenize_json_key(json_key, seq)
      if begins_with_proc_prefix?(json_key)
        seq.push(Token.new(:"&", :proc_prefix))
        tokenize_words_and_special_forms(get_prefixed_string(json_key), seq)
      else
        seq.push(Token.new(json_key.freeze, :key_word))
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
        seq.push(Token.new(json_value, :true))
      elsif json_value.is_a? Numeric
        seq.push(Token.new(json_value, :number))
      elsif json_value.is_a? Array
        seq.push(Token.new(json_value, :array))
      elsif json_value.is_a? FalseClass
        seq.push(Token.new(json_value, :false))
      elsif json_value.nil?
        seq.push(Token.new(json_value, :null))
      elsif json_value.is_a? String
        tokenize_json_string(json_value.freeze, seq)
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
        seq.push(Token.new(other_chars, :other_chars))
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
      case next_char(json_string).intern
      when :"$"
        seq.push(Token.new(:"$", :variable_prefix))
      when :" "
        seq.push(Token.new(:" ", :whitespace))
      end
    end

    def match_other_chars?(string)
      string.match(/\A[\W]*/).to_s == "" ? false : true
    end

    def get_other_chars_and_string(string)
      other_chars = string.match(/\A[\W]*/)
      rest_start_index = other_chars.end(0)
      [other_chars.to_s.freeze, string[rest_start_index..-1].freeze]
    end

    def next_char(string)
      string[0].freeze
    end

    def get_next_word_and_string(string)
      next_word = string.match(/[a-zA-Z\-_.\d]*/)
      rest_start_index = next_word.end(0)
      [next_word.to_s.freeze, string[rest_start_index..-1].freeze]
    end
    
    def tokenize_words_and_special_forms(json_string, seq)
      special_form = match_special_form(json_string)
      case special_form.intern
      when :doc
        seq.push(Token.new(json_string, :doc))
      when :let
        seq.push(Token.new(json_string, :let))
      when :ref
        seq.push(Token.new(json_string, :ref)) 
      when :""
        seq.push(Token.new(json_string, :word))
      end      
    end

    def match_special_form(string)
      string.match(/\A(let|ref|doc)/).to_s.freeze
    end
  end
  
end
