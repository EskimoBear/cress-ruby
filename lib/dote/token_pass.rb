require_relative 'dote_grammars'
require_relative 'tokenizer'
require_relative 'program_errors'
require_relative '../../utils/typed_seq'

module Dote::TokenPass

  extend Tokenizer

  Token = Dote::LexemeCapture::Token
  TokenSeq = TypedSeq.new_seq(Token)

  LANG = Dote::DoteGrammars.compile_grammar

  class TokenSeq

    include ProgramErrors

    # @return [TokenSeq] self when Token is not found
    # @raise [ProgramErrors::UnknownSpecialForm] unknown_special_forms Token found
    def verify_special_forms(grammar)
      error_token = self.find do |i|
        i.name == LANG.get_rule(:unreserved_procedure_identifier).name
      end
      unless error_token.nil?
        raise UnknownSpecialForm,
        unknown_special_form_error_message(error_token, self, grammar)
      end
      return self
    end

    def unknown_special_form_error_message(token, token_seq, grammar)
      "'#{token.lexeme}' is not a known special_form." \
        .concat(print_error_line(token, token_seq, grammar))
    end

    #Given an alternation rule add rule.name to each referenced
    #  token's alternation_names array.
    #
    #@param rule [Dote::RuleSeq::Rule] alternation rule
    def assign_alternation_names(rule)
      token_names = rule.term_names
      self.map! do |old_token|
        if token_names.include?(old_token.name)
          old_token.alternation_names = [].push(rule.name)
        end
        old_token
      end
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
    #@param rule [Dote::RuleSeq::Rule] An alternation rule
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

    def tokenize_alternation_rule_recur(
          rule,
          input_sequence,
          output_sequence = Dote::TokenPass::TokenSeq.new)

      new_token_name = rule.name
      token_names = rule.term_names

      if input_sequence.include_alt_name?(rule)
        scanned, unscanned = input_sequence.split_before_alt_name(rule)
        output_sequence.concat(scanned)
        head = unscanned.take_while{|i| i.alternation_names.to_a.include? new_token_name}
        new_input = unscanned.drop(head.size)
        new_token = reduce_tokens(new_token_name, *head)
        tokenize_alternation_rule_recur(rule, new_input,
                                        output_sequence.push(new_token).flatten)
      else
        output_sequence.concat(input_sequence)
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

    #Replace inner token sequence of concatenation names with token of rule
    #  name and equivalent lexeme.
    #
    #@param rule [Dote::RuleSeq::Rule] A concatenation rule
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
                                          output_sequence =  Dote::TokenPass::TokenSeq.new)
      token_names = rule.term_names
      match_seq_size = token_names.length
      new_token_name = rule.name
      if input_sequence.seq_match?(*token_names)
        input_sequence.take_with_seq(*token_names) do |m|
          new_input =  input_sequence.drop(m.length)
          matching_tokens = m.last(match_seq_size)
          new_token = reduce_tokens(new_token_name, *matching_tokens)
          m.swap_tail(match_seq_size, new_token)
          new_output = output_sequence.concat(m)
          tokenize_concatenation_rule_recur(rule,
                                            new_input,
                                            new_output)
        end
      else
        output_sequence.concat(input_sequence)
      end
    end

    def reduce_tokens(new_name, *tokens)
      line_no = Dote::TokenPass::TokenSeq
                .new(tokens)
                .get_next_line_no
      indent = Dote::TokenPass::TokenSeq
               .new(tokens)
               .get_next_indent
      combined_lexeme = tokens.each_with_object("") do |i, string|
        string.concat(i.lexeme.to_s)
      end
      LANG.send(new_name)
        .make_token(combined_lexeme.intern,
                    [{:attr => :line_no,
                      :attr_value => line_no},
                     {:attr => :indent,
                      :attr_value => line_no}])
    end

    def get_next_line_no
      line_no = self.last.get_attribute(:line_no)
      if self.last.name == :declaration_divider ||
         self.last.name == :array_start ||
         self.last.name == :program_start ||
         self.last.name == :comma
        line_no = line_no + 1
      end
      line_no
    end

    def get_next_indent
      indent = self.last.get_attribute(:indent)
      if indent.nil?
      elsif self.last.name == :array_start ||
         self.last.name == :program_start ||
         indent = indent + 1
      elsif self.last.name == :array_end ||
            self.last.name == :program_end
        indent = indent - 1
      elsif self.last.name == :whitespace
        print "whitespace here"
      end
      indent
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
    #@return [Dote::TokenPass::TokenSeq, nil] matching token sequence
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
    #@param input_sequence [Dote::TokenPass::TokenSeq] token sequence to
    #analyze
    #@param output_sequence [Dote::TokenPass::TokenSeq] scanned token
    #sequence
    #@return [Dote::TokenPass::TokenSeq, nil] matching token sequence
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
                            output_sequence = Dote::TokenPass::TokenSeq.new)
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
          new_output = output_sequence.concat(scanned)
          if pat_seq == head_names
            output_sequence.concat(unscanned_head)
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
