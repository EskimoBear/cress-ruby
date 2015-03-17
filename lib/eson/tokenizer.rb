require 'oj'
require 'pry'
require_relative 'formal_languages'
require_relative 'token_seq'

#FIXME tokenSeq now moved to Language module
#      All references here are to initialization of Token objects
#      Should this class have direct access to this method or should
#      I put a proxy call that has an appropriate level of access to this
#      information? If I did who should the Tokenizer method ask to create
#      Tokens? It should ask the language module, but why does language need to know
#      about tokens again?
#
#      Language's use of tokenSeq and tokens seems restricted to the parse functions
#
#      AHA!I found the commit where I mentioned this refactoring.
#     Implemented error path for terminal parsing
#
#    Produces a simple error message comparing the expected token name to the actual token name. I would prefer if this could display lexemes instead but the Language module does not have any knowledge of the lexemes. This is strange, since the Tokenizer module magically knows the lexemes of the rules contained in the FormalLanguage module. This relationship needs to be inverted, lexemes should be present in terminal rules and rules should define a method to produce tokens.
#
#      Right. THis means my first step is to introduce lexemes into Language. I need the ide of both a fixed lexeme
#      which is represented by a symbol and a variable lexeme defined by a regex instead of a explicit set of values. This is incorrectly named, the lexeme is the string that the rxp matches, the concept I need included in language is the regexp, which happens to already be there. The problem is that this is really a feature of the token not the language. Maybe it's time to be more explicit about the Rules and Terminals and separate them. NAH.
#       
#      Lexeme Types and Operations -> Language module
#      #new, #make_rule, 
#      Build hand crafted terminal rules from lexeme types -> FormalLanguages module
#      Consistent operation to identify token match -> Tokenizer module
#      Rule#match and Rule#match_rxp? to check rules with both fixed and variable lexeme
#      Should rules produce Tokens based on matches, that would be cool instead of
#      Rule#match we can have Rule#get_token(name, json_lexeme) json_lexeme only necessary
#      when the lexeme is a variable type
#
#      So then is Tokenizer's responsibility just supposed to be the mapping of JSON thingys
#      to eson thingys? What knowledge is required for that? You just need formal languages?
#      Tokenization process is
#      1. Create a set of json symbols from input
#      2. Create a mapping of json symbols to tokens in the formal language
#      3. Implement the map to convert sequence of json symbols to a sequence of tokens
#
#      Operations on lists of tokens which call formal languages -> TokenSeq module
#      Is the above a problem? If I let Rules generate Tokens then the Token type can
#      be located in the Rule or Rule Seq class or like EBNF a high level module in Language
#      which is mixed into Rule.
#
#      Tokenseq currently holds all the passes. It shouldn't. I need to figure out how
#      to organize the multiple pass operations and their relationship to the formal languages.
#      Each pass has a language of rules that it uses, should the passes be mixed into the
#      language during build?
#
#      This way AST can be a sibling subclass of language which has access to Rule and Token
#      Language should require the AST file, AST shouldn't require anything.
module Eson

  module Tokenizer
    
    extend self

    LANG = Eson::FormalLanguages.tokenizer_lang
    
    JsonSymbol = Struct.new :lexeme, :name
    
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
      token_seq = json_symbols_to_token(json_symbol_seq, program_char_seq)
      return token_seq, program_char_seq
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
            seq.push(JsonSymbol.new(:",", :member_comma))
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
            seq.push(JsonSymbol.new(:",", :array_comma))
            seq.push(value_to_json_symbols(i))
          end
        end
      end
      seq.push(JsonSymbol.new(:"]", :array_end))                     
    end
    
    def symbol_length(json_symbol)
      json_symbol.lexeme.size
    end

    def json_symbols_to_token(json_symbol_seq, char_seq)
      json_symbol_seq.each_with_object(TokenSeq.new) do |symbol, seq|
        case symbol.name
        when :object_start
          #seq.push LANG.program_start.make_token
          seq.push(TokenSeq::Token.new(:"{", :program_start))
          pop_chars_string(char_seq, symbol.lexeme) 
        when :object_end
          seq.push(TokenSeq::Token.new(:"}", :program_end))
          pop_chars_string(char_seq, symbol.lexeme) 
        when :array_start
          seq.push(TokenSeq::Token.new(:"[", :array_start))
          pop_chars_string(char_seq, symbol.lexeme) 
        when :array_end
          seq.push(TokenSeq::Token.new(:"]", :array_end))
          pop_chars_string(char_seq, symbol.lexeme) 
        when :colon
          seq.push(TokenSeq::Token.new(:":", :colon))
           pop_chars_string(char_seq, symbol.lexeme)
        when :array_comma
          seq.push(TokenSeq::Token.new(:",", :comma))
          pop_chars_string(char_seq, symbol.lexeme)
        when :member_comma
          seq.push(TokenSeq::Token.new(:",", :end_of_line))
          pop_chars_string(char_seq, symbol.lexeme)
        when :JSON_key
          tokenize_json_key(symbol.lexeme, seq, char_seq)
        when :JSON_value
          tokenize_json_value(symbol.lexeme, seq, char_seq)
        end
      end
    end

    def update_seqs(token, token_seq, char_seq)
      token_seq.push(token)
      pop_chars_string(char_seq, token.lexeme)
    end
    
    def pop_chars_string(char_seq, matched_string)
      char_seq.slice!(0, matched_string.size)
    end

    def tokenize_json_key(json_key, seq, char_seq)
      if begins_with_proc_prefix?(json_key)
        seq.push(TokenSeq::Token.new(:"&", :proc_prefix))
        char_seq.slice!(0, 1)
        tokenize_special_form(get_prefixed_string(json_key), seq, char_seq)
      else
        seq.push(TokenSeq::Token.new("\"#{json_key.freeze}\"", :key_string))
        char_seq.slice!(0, json_key.length)
      end
    end

    def begins_with_proc_prefix?(string)
      string[0] == "&"
    end
    
    def get_prefixed_string(string)
      string[1..-1]     
    end

    def tokenize_special_form(json_string, seq, char_seq)
      case json_string
      when LANG.doc.rxp
        #seq.push LANG.make_token(json_string)
        seq.push(TokenSeq::Token.new(json_string, LANG.doc.name))
        pop_chars_string(char_seq, json_string)
      when LANG.let.rxp
        seq.push(TokenSeq::Token.new(json_string, LANG.let.name))
        pop_chars_string(char_seq, json_string)
      when LANG.ref.rxp
        seq.push(TokenSeq::Token.new(json_string, LANG.ref.name))
        pop_chars_string(char_seq, json_string)
      else
        seq.push(TokenSeq::Token.new(json_string, LANG.unknown_special_form.name))
        pop_chars_string(char_seq, json_string)
      end      
    end

    def tokenize_json_value(json_value, seq, char_seq)
      if json_value.is_a? TrueClass
        seq.push(TokenSeq::Token.new(json_value, :true))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.is_a? Numeric
        seq.push(TokenSeq::Token.new(json_value, :number))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.is_a? FalseClass
        seq.push(TokenSeq::Token.new(json_value, :false))
        char_seq.slice!(0, json_value.to_s.size)
      elsif json_value.nil?
        seq.push(TokenSeq::Token.new("null", :null))
        char_seq.slice!(0, :null.to_s.size)
      elsif json_value.is_a? String
        tokenize_json_string(json_value.freeze, seq, char_seq)
      end
    end
    
    def tokenize_json_string(json_string, seq, char_seq)
      case json_string
      when LANG.whitespace.rxp
        lexeme = LANG.whitespace.match(json_string).to_s.intern
        seq.push(TokenSeq::Token[lexeme, LANG.whitespace.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      when LANG.variable_prefix.rxp
        lexeme = LANG.variable_prefix.match(json_string).to_s.intern
        seq.push(TokenSeq::Token[lexeme, LANG.variable_prefix.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      when LANG.other_chars.rxp
        lexeme = LANG.other_chars.match(json_string).to_s.intern
        seq.push(TokenSeq::Token[lexeme, LANG.other_chars.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      when LANG.word.rxp
        lexeme = LANG.word.match(json_string).to_s.intern
        seq.push(TokenSeq::Token[lexeme, LANG.word.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      end
    end
    
    def get_rest(json_string, matched_string)
      json_string[matched_string.size..-1]
    end
  end
  
end
