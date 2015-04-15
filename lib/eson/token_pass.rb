require_relative 'eson_grammars'
require_relative 'tokenizer'
require_relative 'error_pass'

module Eson::TokenPass

  extend Tokenizer

  LANG = Eson::EsonGrammars.tokenizer_lang
  
  class TokenSeq < Array

    include Eson::ErrorPass
    
    WrongElementType = Class.new(StandardError)
    
    Token = Eson::LexemeCapture::Token

    def self.new(obj=nil)
      if obj.nil?
        super []
      else
        array = super
        unless self.all_tokens?(array)
          raise WrongElementType, self.new_item_error_message
        end
        array
      end
    end

    def self.all_tokens?(seq)
      seq.all?{|i| i.class == Token}
    end

    def self.new_item_error_message
      "One or more of the given array elements are not of the type #{Eson::LexemeCapture::Token}"
    end

    def get_program_line(line_no)
      take_while{|i| i.line_number == line_no}
        .each_with_object(""){|i, acc| acc.concat(i.lexeme.to_s)}
    end

    def print_program
      if self.none?{|i| i.line_number.nil?}
        self.slice_when{|i, j| i.line_number != j.line_number}
          .map{|i| i.each_with_object(""){|j, acc| acc.concat(j.lexeme.to_s)}}
          .each_with_index{|item, i| puts "\t#{i+1}:  #{item}"}
      end
    end
    
    #Add line number metadata to each token
    #
    #@eskimobear.specification
    # T, input token sequence
    # O, output token sequence
    # t, end_of_line token
    # ets, sequence begins with T start and ends with end_of_line
    # L, line number integer
    #
    # Init : length(T) > 0
    #      : length(O) = 0
    #        L = 1
    # Next : when T contains end_of_line
    #        T' = T - ets - t
    #        O' = O + label(ets, L)
    #        L' = L + 1
    #        when T does not contain end_of_line
    #        T' = []
    #        O' = O + label(T, L)
    def add_line_numbers
      self.replace add_line_numbers_recur(1, self.clone)        
    end

    def add_line_numbers_recur(line_no, input_seq,
                               output_seq = Eson::TokenPass::TokenSeq.new)
      if input_seq.include_token?(:end_of_line)
        scanned, unscanned = input_seq.split_after_token(:end_of_line)
        scanned.map{|i| i.line_number = line_no}
        add_line_numbers_recur(line_no + 1, unscanned,
                               output_seq.push(scanned).flatten)                              
      else
        lined_seq = input_seq.each{|i| i.line_number = line_no}
        output_seq.push(lined_seq).flatten
      end
    end

    #Add a string_delimiter token before and after each sequence of
    #  possible sub_strings
    #
    #@eskimobear.specification
    #T, inpuut token sequence
    #O, output token sequence
    #ets, sequence between T start and sub_string
    #ss, sequence of sub_string tokens
    #
    # Init : length(T) > 0
    #        length(O) = 0
    # Next : when T contains sub_string
    #        T' = T - ets
    #        O' = O + ets + string_delimiter
    #        when head(T) = ss
    #        T' = T - ss
    #        O' = O + ss + string_delimiter
    #        when T does not contain sub_string
    #        T' = []
    #        O' = O + T
    def insert_string_delimiters
      self.replace insert_string_delimiters_recur(Eson::EsonGrammars.e4.sub_string, self.clone)  
    end

    def insert_string_delimiters_recur(rule, input_sequence,
                                       output_sequence = Eson::TokenPass::TokenSeq.new)
      if input_sequence.include_alt_name?(rule)
        scanned, unscanned = input_sequence.split_before_alt_name(rule)
        
        delimiter = Eson::EsonGrammars.e4.string_delimiter.make_token("\"")
        delimiter.line_number = scanned.get_next_line_number
        output_sequence.push(scanned).push(delimiter).flatten!
        head = unscanned.take_while{|i| i.alternation_names.to_a.include?(rule.name)}
        new_input = unscanned.drop(head.length)
        insert_string_delimiters_recur(rule,
                                       new_input,
                                       output_sequence.push(head).push(delimiter).flatten)
      else
        output_sequence.push(input_sequence).flatten
      end        
    end
    
    def label_sub_strings
      assign_alternation_names(Eson::EsonGrammars.e4.sub_string)
    end
    
    #Given an alternation rule add rule.name to each referenced
    #  token's alternation_names array.
    #
    #@param rule [Eson::RuleSeq::Rule] alternation rule
    def assign_alternation_names(rule)
      token_names = rule.term_names
      new_token_name = rule.name
      self.map! do |old_token|
        if token_names.include?(old_token.name)
          old_token.alternation_names = [].push(rule.name)
        end
        old_token
      end
    end
    
    def tokenize_variable_identifiers
      tokenize_rule(LANG.variable_identifier)
    end

    def tokenize_proc_identifiers
      tokenize_rule(LANG.proc_identifier)
      self.each do |i|
        if i.name == :proc_identifier
          old_lexeme = i.lexeme.to_s
          i.lexeme = "\"#{old_lexeme}\""
        end
      end
    end

    def tokenize_word_forms
      tokenize_rule(LANG.word_form)
    end

    def tokenize_special_forms
      tokenize_rule(LANG.special_form)
    end

    def tokenize_rule(rule)
      if rule.alternation_rule?
        tokenize_alternation_rule(rule)
      elsif rule.concatenation_rule?
        tokenize_concatenation_rule(rule)
      end
    end

    #Replace tokens of :choice names with token of rule name and
    #  equivalent lexeme. Reduce all repetitions to a single token. 
    #  
    #@param rule [Eson::RuleSeq::Rule] An alternation rule 
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
    #        O' = O + ntt AND ntt = combine(ots)
    #        When T does not contain ot
    #        T' = []
    #        O' = O + T
    # Final : length(T) = 0
    def tokenize_alternation_rule(rule)
      assign_alternation_names(rule)
      self.replace tokenize_alternation_rule_recur(rule, self.clone)
    end

    def tokenize_alternation_rule_recur(rule, input_sequence,
                                        output_sequence = Eson::TokenPass::TokenSeq.new)
      new_token_name = rule.name
      token_names = rule.term_names

      if input_sequence.include_alt_name?(rule)
        scanned, unscanned = input_sequence.split_before_alt_name(rule)
        output_sequence.push(scanned).flatten!
        head = unscanned.take_while{|i| i.alternation_names.to_a.include? new_token_name}
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

    def split_after_token(token_name)
      if self.include_token?(token_name)
        split_point = get_token_index(token_name) + 1
        head = self.take(split_point)
        tail = self[split_point..-1]
        return head, tail
      else
        nil
      end
    end

    def split_before_alt_name(rule)
      if self.include_alt_name?(rule)
        split_point = get_alt_name_index(rule.name)
        head = self.take(split_point)
        tail = self[split_point..-1]
        return head, tail
      end
    end

    def include_alt_name?(rule)
      get_alt_name_token(rule.name) ? true : false
    end

    def alt_names
      self.map{|i| i.alternation_names.to_a}
    end

    def get_alt_name_token(rule_name)
      index = get_alt_name_index(rule_name)
      if index.nil?
        nil
      else
        self[index]
      end
    end

    def get_alt_name_index(rule_name)
      alt_names.find_index{|i| i.include? rule_name}
    end
    
    
    #Replace inner token sequence of :none names with token of rule
    #  name and equivalent lexeme.
    #
    #@param rule [Eson::RuleSeq::Rule] A concatenation rule
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
                                          output_sequence =  Eson::TokenPass::TokenSeq.new)
      token_names = rule.term_names
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
      line_no = Eson::TokenPass::TokenSeq.new(tokens).get_next_line_number
      combined_lexeme = tokens.each_with_object("") do |i, string|
        string.concat(i.lexeme.to_s)
      end
      Token[combined_lexeme.intern, new_name, nil, line_no]
    end

    def get_next_line_number
      end_token = self.last
      if end_token.name == :end_of_line       
        end_token.line_number + 1
      else
        end_token.line_number
      end
    end
    
    def swap_tail(tail_length, new_tail)
      self.pop(tail_length)
      self.push(new_tail).flatten
    end

    def seq_match?(*token_names)
      take_with_seq(*token_names) ? true : false
    end

    #Returns a token sequence that begins at the head of self and
    #ends with the token_names. Delegates to #take_with_seq_recur.
    #@see take_with_seq_recur
    #@param token_names [Array<Symbols>] sequence of token names to match
    #@yield [t] matching token sequence
    #@return [Eson::TokenPass::TokenSeq, nil] matching token sequence
    #or nil
    def take_with_seq(*token_names)
      if block_given?
        yield take_with_seq_recur(token_names, self.clone)
      else
        take_with_seq_recur(token_names, self.clone)
      end
    end

    #Scans a input_sequence recursively for a token sequence that
    #begins at head and ends with the token names pat_seq.
    #@param pat_seq [Array<Symbols>] sequence of token names to match
    #@param input_sequence [Eson::TokenPass::TokenSeq] token sequence to
    #analyze
    #@param output_sequence [Eson::TokenPass::TokenSeq] scanned token
    #sequence
    #@return [Eson::TokenPass::TokenSeq, nil] matching token sequence
    #or nil
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
                            output_sequence = Eson::TokenPass::TokenSeq.new)
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
end
