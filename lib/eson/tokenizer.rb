require 'oj'
require 'pry'
require_relative 'language'

module Eson

  module Tokenizer

    extend self

    JsonSymbol = Struct.new "JsonSymbol", :lexeme, :name
    
    Token = Struct.new "Token", :lexeme, :name

    class TokenSeq < Array

      def tokenize_variable_identifiers
        tokenize_rule(LANG.variable_identifier)
      end

      def tokenize_word_form
        tokenize_rule(LANG.word_form)
      end

      def tokenize_rule(rule)
        if rule.alternation?
          tokenize_alternation_rule(rule)
        elsif rule.concatenation?
          tokenize_concatenation_rule(rule)
        end
      end

      #Replace tokens of :choice names with token of rule name and
      #  equivalent lexeme. Reduce all repetitions to a single token. 
      #  
      #@param rule [Eson::Language::RuleSeq::Rule] An alternation rule 
      #@return [Eson::Tokenizer::TokenSeq] A sequence of tokens for E3 
      #@eskimobear.specification
      # Original token sequence, T
      # Output token sequence, O
      # Old token, ot
      # Token sequence of ot, ots
      # Sequence between T start and ot, ets
      # Single token for token sequence ots, ntt
      # Init : length(T) < 0
      #        length(O) = 0
      # Next : When T contains ot
      #        T' = T - ets
      #        O' = O + ets
      #        When head(T) = ots
      #        T' = T - ots
      #        O' = O + nts
      #        O' = O + ntt AND ntt = combine(ots)
      #        When T does not contain ot
      #        T' = []
      #        O' = O + T
      # Final : length(T) = 0
      def tokenize_alternation_rule(rule)
        token_names = rule.sequence.map{|i| i.rule_name}
        new_token_name = rule.name
        self.map! do |old_token|
          if token_names.include?(old_token.name)
            old_token.name = new_token_name
            old_token
          else
            old_token
          end
        end
        self.replace tokenize_alternation_rule_recur(rule, self.clone)
      end

      def tokenize_alternation_rule_recur(rule, input_sequence,
                                          output_sequence = Eson::Tokenizer::TokenSeq.new)
        new_token_name = rule.name
        token_names = rule.sequence.map{|i| i.rule_name}
        
        if input_sequence.include_token?(new_token_name)
          scanned, unscanned = input_sequence.split_before_token(new_token_name)         
          output_sequence.push(scanned).flatten!
          head = unscanned.take_while{|i| i.name == new_token_name}
          new_input = unscanned.drop(head.size)
          new_token = reduce_tokens(new_token_name, *head)
          tokenize_alternation_rule_recur(rule, new_input,
                                          output_sequence.push(new_token).flatten)
        else
          output_sequence.push(input_sequence).flatten
        end
      end

      def split_before_token(token_name)
        if self.include_token?(token_name)
          split_point = get_token_index(token_name)
          head = self.take(split_point)
          tail = self[split_point..-1]
          return head, tail
        else
          nil
        end
      end
      
      #Replace inner token sequence of :none names with token of rule
      #  name and equivalent lexeme.
      #
      #@param rule [Eson::Language::RuleSeq::Rule] A concatenation rule 
      #@return [Eson::Tokenizer::TokenSeq] A token sequence
      #@eskimobear.specification
      # Original token sequence, T
      # Output token sequence, O
      # Inner token sequence, m
      # First token of m, m_start
      # Sequence between T start and m_start, ets
      # Single token for token sequence, mt
      # Init : length(T) < 0
      #        length(O) = 0
      # Next : when T contains m
      #        T' = T - ets
      #        O' = O + ets + mt AND mt = reduce(m)
      #        otherwise
      #        T' = []
      #        O' = O + T
      def tokenize_concatenation_rule(rule)
        self.replace tokenize_concatenation_rule_recur(rule, self.clone)
      end

      def tokenize_concatenation_rule_recur(rule, input_sequence,
                                            output_sequence =  Eson::Tokenizer::TokenSeq.new)
        token_names = rule.sequence.map{|i| i.rule_name}
        match_seq_size = token_names.length
        new_token_name = rule.name
        if input_sequence.seq_match?(*token_names)         
          input_sequence.take_with_seq(*token_names) do |m|
            new_input =  input_sequence.drop(m.length)
            matching_tokens = m.last(match_seq_size)
            new_token = reduce_tokens(new_token_name, *matching_tokens)
            m.swap_tail(match_seq_size, new_token)
            new_output = output_sequence.push(m).flatten
            tokenize_concatenation_rule_recur(rule,
                                              new_input,
                                              new_output)
          end
        else
          output_sequence.push(input_sequence).flatten
        end
      end

      def reduce_tokens(new_name, *tokens)
        combined_lexeme = tokens.each_with_object("") do |i, string|
          string.concat(i.lexeme.to_s)
        end
        Token[combined_lexeme.intern, new_name]
      end
      
      def swap_tail(tail_length, new_tail)
        self.pop(tail_length)
        self.push(new_tail).flatten
      end

      def seq_match?(*token_names)
        take_with_seq(*token_names) ? true : false
      end

      def take_with_seq(*token_names)
        if block_given?
          yield take_with_seq_recur(token_names, self.clone)
        else
          take_with_seq_recur(token_names, self.clone)
        end
      end

      #Returns a token sequence that begins at head of sequence and
      #  ends with the pattern sequence.
      #@param token_names [Array<Symbols>] sequence of token names to match
      #@return [Eson::Tokenizer::TokenSeq] sequence ending with token
      #  names pattern.
      #Currently exits on first partially failing pattern it matches
      #Need to start another scan when first fails
      #@eskimobear.specification
      # T, input token sequence
      # et,tokens in T
      # ets, sequence of et between T start and p_start
      # S, scanned token sequence
      # p, pattern sequence
      # p_start, first token of p
      # P, output sequence ending in p
      # Init : length(T) > 0
      #        length(S) = 0
      #        length(P) = 0
      # Next : when T contains p_start
      #        T' = T - ets
      #        S' = S + ets 
      #        when head(T') == p
      #        P = S' + p
      #        T' = T
      #        S' = S
      #        when head(T') != p
      #        T' = T - p_start
      #        S' = S + p_start
      #        when T does not contain p_start
      #        T' = []
      #        S' = S + T
      #        P = T'
      def take_with_seq_recur(pat_seq, input_sequence,
                         output_sequence = Eson::Tokenizer::TokenSeq.new)
        pat_start = pat_seq.first
        if input_sequence.include_token?(pat_start)
          scanned, unscanned = input_sequence.split_before_token(pat_start)
          unscanned_head = unscanned.take(pat_seq.length)
          head_names = unscanned_head.map{|i| i.name}
          if scanned.empty?
            if pat_seq == head_names
              output_sequence.push(unscanned_head).flatten!
              if block_given?
                yield output_sequence
              else
                return output_sequence
              end
            else
              take_with_seq_recur(pat_seq,
                             unscanned.drop(1),
                             output_sequence.push(unscanned.first).flatten)
            end
          else
            new_input = unscanned
            new_output = output_sequence.push(scanned).flatten!
            if pat_seq == head_names
              output_sequence.push(unscanned_head).flatten!
              if block_given?
                yield output_sequence
              else
                return output_sequence
              end
            else
              take_with_seq_recur(pat_seq,
                             unscanned,
                             new_output)
            end
          end 
        else
          nil
        end
      end
      
      def include_token?(token_name)
        get_token(token_name) ? true : false
      end

      def get_token(token_name)
        self.find{|i| i.name == token_name}
      end

      def last_token?(token_name)
        get_token_index(token_name) == (self.length - 1)
      end

      def get_token_index(token_name)
        self.find_index{|i| i.name == token_name}
      end

      def first_token?(token_name)
        self.first.name == token_name
      end
    
      def swap_tail(tail_length, new_tail)
        self.pop(tail_length)
        self.push(new_tail).flatten
      end
    end
    
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
      symbol_seq.each_with_object(TokenSeq.new) do |symbol, seq|
        case symbol.name
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
        seq.push(Token.new(json_key.freeze, :key_string))
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
      special_form = LANG.special_form.match_start(json_string).to_s
      case special_form
      when LANG.doc.rxp
        seq.push(Token.new(json_string, LANG.doc.name))
        pop_chars_string(char_seq, json_string)
      when LANG.let.rxp
        seq.push(Token.new(json_string, LANG.let.name))
        pop_chars_string(char_seq, json_string)
      when LANG.ref.rxp
        seq.push(Token.new(json_string, LANG.ref.name))
        pop_chars_string(char_seq, json_string)
      else
        seq.push(Token.new(json_string, LANG.unknown_special_form.name))
        pop_chars_string(char_seq, json_string)
      end      
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
      elsif LANG.whitespace.match_rxp?(json_string)
        lexeme = LANG.whitespace.match(json_string).to_s.intern
        seq.push(Token[lexeme, LANG.whitespace.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      elsif LANG.variable_prefix.match_rxp?(json_string)
        lexeme = LANG.variable_prefix.match(json_string).to_s.intern
        seq.push(Token[lexeme, LANG.variable_prefix.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      elsif LANG.other_chars.match_rxp?(json_string)
        lexeme = LANG.other_chars.match(json_string).to_s.intern
        seq.push(Token[lexeme, LANG.other_chars.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      elsif LANG.word.match_rxp?(json_string)
        lexeme = LANG.word.match(json_string).to_s.intern
        seq.push(Token[lexeme, LANG.word.name])
        pop_chars_string(char_seq, lexeme)
        tokenize_json_string(get_rest(json_string, lexeme), seq, char_seq)
      end
    end

    def pop_chars_string(char_seq, matched_string)
      char_seq.slice!(0, matched_string.size)
    end
    
    def get_rest(json_string, matched_string)
      json_string[matched_string.size..-1]
    end
  end
  
end
