require 'oj'
require_relative 'language'

module Eson

  module Tokenizer

    extend self

    JsonSymbol = Struct.new "JsonSymbol", :lexeme, :type
    Token = Struct.new "Token", :lexeme, :type

    LANG = Language.tokenizer_lang
    
    #Converts an eson program into a sequence of eson tokens
    #@param eson_program [String] string provided to Eson#read
    #@return [Array<Array>] A pair of token sequence and the input char sequence
    #@eskimobear.specification
    # Eson token set, ET is a set of the eson terminal symbols defined below
    # Eson token, et is a sequence of characters existing in ET
    # label(et) maps the character sequence to the name of the matching
    #   eson terminal symbol
    # Input program, p, a valid JSON string 
    # Input sequence, P, a sequence of characters in p
    # Token sequence, T
    #
    # Init : length(P) > 0
    #        length(T) = 0
    # Next : et = P - 'P AND T' = T + label(et)
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
      eson_program.freeze
      program_json_hash = Oj.load(eson_program)
      program_char_seq = get_program_char_sequence(program_json_hash)
      json_symbol_seq = get_json_symbol_sequence(program_json_hash)
      token_seq = tokenize_json_symbols(json_symbol_seq, program_char_seq)
      [token_seq, program_char_seq]
    end

    private

    def get_program_char_sequence(hash)
      seq = Array.new
      compact_string = Oj.dump(hash)
      compact_string.each_char {|c| seq << c}
      seq.reject{|i| i.match(/"/)}
    end

    def get_json_symbol_sequence(hash)
      Array.new.push(JsonSymbol.new(:"{", :object_start))
        .push(members_to_json_symbols(hash))
        .push(JsonSymbol.new(:"}", :object_end))
        .flatten
    end

    def members_to_json_symbols(json_pairs)
      seq = Array.new
      unless json_pairs.empty?
        seq.push pair_to_json_symbols(json_pairs.first)
        rest = json_pairs.drop(1)
        unless rest.empty?
          rest.each_with_object(seq) do |i, seq|
            seq.push(JsonSymbol.new(:",", :comma))
              .push(pair_to_json_symbols(i))
          end
        end
      end
      seq
    end

    def pair_to_json_symbols(json_pair)
      json_value = json_pair[1]
      value = value_to_json_symbols(json_value)
      Array.new.push(JsonSymbol.new(json_pair.first, :JSON_key))
        .push(JsonSymbol.new(:":", :colon))
        .push(value)
        .flatten
    end

    def value_to_json_symbols(json_value)
      if json_value.is_a? Hash
        get_json_symbol_sequence(json_value)
      elsif json_value.is_a? Array
        array_to_json_symbols(json_value)
      else
        JsonSymbol.new(json_value, :JSON_value)
      end
    end

    def array_to_json_symbols(json_array)
      seq = Array.new.push(JsonSymbol.new(:"[", :array_start))
      unless json_array.empty?
        seq.push(value_to_json_symbols(json_array.first))
        unless json_array.drop(1).empty?
          json_array.drop(1).each do |i|
            seq.push(JsonSymbol.new(:",", :comma))
            seq.push(value_to_json_symbols(i))
          end
        end
      end
      seq.push(JsonSymbol.new(:"]", :array_end))                     
    end
    
    def symbol_length(json_symbol)
      json_symbol.lexeme.size
    end
    
    def tokenize_json_symbols(symbol_seq, char_seq)
      symbol_seq.each_with_object(Array.new) do |symbol, seq|
        case symbol.type
        when :object_start
          seq.push(Token.new(:"{", :program_start))
          pop_chars(symbol, char_seq) 
        when :object_end
          seq.push(Token.new(:"}", :program_end))
          pop_chars(symbol, char_seq)
        when :array_start
          seq.push(Token.new(:"[", :array_start))
          pop_chars(symbol, char_seq)
        when :array_end
          seq.push(Token.new(:"]", :array_end))
          pop_chars(symbol, char_seq)
        when :colon
          seq.push(Token.new(:":", :colon))
          pop_chars(symbol, char_seq) 
        when :comma
          seq.push(Token.new(:",", :comma))
          pop_chars(symbol, char_seq) 
        when :JSON_key
          tokenize_json_key(symbol.lexeme, seq, char_seq)
        when :JSON_value
          tokenize_json_value(symbol.lexeme, seq, char_seq)
        end
      end
    end

    def pop_chars(symbol, char_seq)
      char_seq.slice!(0, symbol_length(symbol))
    end

    def tokenize_json_key(json_key, seq, char_seq)
      if begins_with_proc_prefix?(json_key)
        seq.push(Token.new(:"&", :proc_prefix))
        char_seq.slice!(0, 1)
        tokenize_special_forms(get_prefixed_string(json_key), seq, char_seq)
      else
        seq.push(Token.new(json_key.freeze, :key_word))
        char_seq.slice!(0, json_key.length)
      end
    end

    def begins_with_proc_prefix?(string)
      string[0] == "&"
    end
    
    def get_prefixed_string(string)
      string[1..-1]     
    end

    def tokenize_special_forms(json_string, seq, char_seq)
      special_form = match_special_form(json_string)
      case special_form.intern
      when :doc
        seq.push(Token.new(json_string, :doc))
        char_seq.slice!(0, 3)
      when :let
        seq.push(Token.new(json_string, :let))
        char_seq.slice!(0, 3)
      when :ref
        seq.push(Token.new(json_string, :ref))
        char_seq.slice!(0, 3)
      when :""
          seq.push(Token.new(json_string, :unknown_special_form))
          char_seq.slice!(0, json_string.length)
      end      
    end

    def match_special_form(string)
      rxp = LANG.make_alternation([:let, :ref, :doc])
      string.match(rxp).to_s.freeze
    end

    def tokenize_json_value(json_value, seq, char_seq)
      if json_value.is_a? TrueClass
        seq.push(Token.new(json_value, :true))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.is_a? Numeric
        seq.push(Token.new(json_value, :number))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.is_a? FalseClass
        seq.push(Token.new(json_value, :false))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.nil?
        seq.push(Token.new(json_value, :null))
        char_seq.slice!(0, :null.to_s.size)
      elsif json_value.is_a? String
        tokenize_json_string(json_value.freeze, seq, char_seq)
      elsif json_value.is_a? Hash
        tokenize_json_hash(json_value, seq, char_seq)
      end
    end
    
    def tokenize_json_string(json_string, seq, char_seq)
      if json_string.empty?
        seq
      elsif match_leading_whitespace_or_variable_prefix?(json_string)
        tokenize_prefix(json_string, seq, char_seq)
        tokenize_json_string(get_prefixed_string(json_string), seq, char_seq)
      elsif match_other_chars?(json_string)
        other_chars, rest = get_other_chars_and_string(json_string)
        seq.push(Token.new(other_chars, :other_chars))
        char_seq.slice!(0, other_chars.length)
        tokenize_json_string(rest, seq, char_seq)
      else
        next_word, rest = get_next_word_and_string(json_string)
        seq.push(Token.new(next_word, :word))
        char_seq.slice!(0, next_word.length)
        tokenize_json_string(rest, seq, char_seq)
      end
    end

    def match_leading_whitespace_or_variable_prefix?(string)
      rxp = LANG.make_alternation([:whitespace, :variable_prefix])
      string.match(rxp).to_s == "" ? false : true
    end

    def tokenize_prefix(json_string, seq, char_seq)
      case next_char(json_string).intern
      when :"$"
          seq.push(Token.new(:"$", :variable_prefix))
          char_seq.slice!(0, 1)
      when :" "
          seq.push(Token.new(:" ", :whitespace))
          char_seq.slice!(0, 1)
      end
    end

    def match_other_chars?(string)
      LANG.other_chars.match_rxp?(string)
    end

    def get_other_chars_and_string(string)
      other_chars = LANG.other_chars.match(string)
      rest_start_index = other_chars.end(0)
      [other_chars.to_s.freeze, string[rest_start_index..-1].freeze]
    end

    def next_char(string)
      string[0].freeze
    end

    def get_next_word_and_string(string)
      next_word = LANG.word.match(string)
      rest_start_index = next_word.end(0)
      [next_word.to_s.freeze, string[rest_start_index..-1].freeze]
    end
  end
  
end
