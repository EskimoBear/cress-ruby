module Eson

  module Language
    
    extend self

    module LanguageOperations

      def get_rule(rule_name)
        rule_seq.get_rule(rule_name)
      end
      
      def rule_seq
        Eson::Language::RuleSeq.new self.values
      end

      def make_top_rule(rule_name)
        self.class.send(:define_method, :top_rule){get_rule(rule_name)}
        self
      end

      def to_s
        rule_list = rule_seq.map{|i| i.to_s}
        "#{self.class.to_s.gsub(/Struct::/, "")} has the following production rules:\n#{rule_list.join("\n")}"
      end              
    end

    #Operations and data structures for the lexeme field
    #  of Eson::Language::RuleSeq::Rule. Token has a
    #  regexp that matches a fixed lexeme or a set of strings. 
    module LexemeCapture

      Token = Struct.new :lexeme, :name, :alternation_names, :line_number

      def make_token(lexeme)
        Token.new(lexeme, @name)
      end

      def match_token(stirng)
        #if match_rxp?(string)
        lexeme = self.match(string).to_s.intern
        self.make_token(lexeme)
        #end
      end
      
      def match(string)
        string.match(rxp)
      end
      
      def rxp
        apply_at_start(@start_rxp)
      end
      
      def match_rxp?(string)
        regex_match?(self.rxp, string)
      end

      def match_start(string)
        if self.nonterminal?
          string.match(@start_rxp)
        else
          nil
        end
      end

      def regex_match?(regex, string)
        #does not catch zero or more matches that return "", the empty string
        (string =~ apply_at_start(regex)).nil? ? false : true
      end      

      def apply_at_start(regex)
        /\A#{regex.source}/
      end
    end

    #Operations and data structures for the ebnf field
    #  of the Eson::Language::RuleSeq::Rule
    module EBNF

      Terminal = Struct.new(:rule_name)
      NonTerminal = Struct.new(:rule_name)
            
      ConcatenationRule = Struct.new(:term_list)
      AlternationRule = Struct.new(:term_set)
      RepetitionRule = Struct.new(:term)
      OptionRule = Struct.new(:term)

      def terminal?
        self.ebnf.nil?
      end
      
      def nonterminal?
        !terminal?
      end

      def nullable?
        if self.option_rule? || self.repetition_rule?
          true
        elsif @first_set.include? :nullable
          true
        else
          false
        end
      end

      def term_names
        if self.terminal?
          nil
        elsif alternation_rule?
          self.ebnf.term_set.map{|i| i.rule_name}
        elsif concatenation_rule?
          self.ebnf.term_list.map{|i| i.rule_name}
        elsif repetition_rule? || option_rule?
          [ebnf.term.rule_name]
        end
      end

      #FIXME this no longer works as terminals which have been
      #converted from nonterminals have an undefined @start_rxp
      def to_s       
        "#{name} := #{self.ebnf_to_s};"
      end

      def ebnf_to_s
        if terminal?
          "\"#{rxp.source.gsub(/\\/, "")}\""
        elsif alternation_rule?
          terms = ebnf.term_set
          join_rule_names(terms, " | ")
        elsif concatenation_rule?
          terms = ebnf.term_list
          join_rule_names(terms, ", ")
        elsif repetition_rule?
          "{#{ebnf.term.rule_name}}"
        elsif option_rule?
          "[#{ebnf.term.rule_name}]"
        end
      end

      def alternation_rule?
        self.ebnf.instance_of? AlternationRule
      end

      def concatenation_rule?
        self.ebnf.instance_of? ConcatenationRule
      end

      def repetition_rule?
        self.ebnf.instance_of? RepetitionRule
      end

      def option_rule?
        self.ebnf.instance_of? OptionRule
      end

      def join_rule_names(terms, infix="")
        initial = terms.first.rule_name.to_s
        rest = terms.drop(1)
        rest.each_with_object(initial){|i, memo| memo.concat(infix).concat(i.rule_name.to_s)}
      end
    end
    
    class RuleSeq < Array

      ItemError = Class.new(StandardError)
      ConversionError = Class.new(StandardError)
      
      #EBNF production rule representation for terminals and non-terminals
      class Rule

        include EBNF
        include LexemeCapture

        ParseError = Class.new(StandardError)
        UnmatchedFirstSetError = Class.new(StandardError)
        JointFirstSetError = Class.new(StandardError)

        attr_accessor :name, :first_set, :partial_status, :ebnf, :follow_set

        #@param name [Symbol] name of the production rule
        #@param sequence [Array<Terminal, NonTerminal>] list of terms this
        #  rule references, this list is empty when the rule is a terminal
        #@param start_rxp [Regexp] regexp that accepts valid symbols for this
        #  rule
        #@param partial_status [Boolean] true if any terms are not defined as a
        #  rule or descend from terms with partial_status in their associated rule.
        #  If a rule has a partial_status then it's full first_set is only
        #  computed when a formal language is derived from said rule.
        #@param ebnf [Eson::EBNF] ebnf definition of the rule, each defintion
        #  contains only one control, thus a rule can be one of the four control
        #  types:- concatenation, alternation, repetition and option.
        def initialize(name, start_rxp=nil, partial_status=nil, ebnf=nil)
          @name = name
          @ebnf = ebnf
          @start_rxp = start_rxp
          @first_set = terminal? ? [name] : []
          @partial_status = terminal? ? false : partial_status
          @follow_set = []
        end

        def self.new_terminal_rule(name, start_rxp)
          self.new(name, start_rxp) 
        end

        #Return a Token sequence that is a legal instance of
        #  the rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        #@eskimobear.specification
        # T, input token sequence
        # S, sub-sequence matching rule
        # E, sequence of error tokens
        # r_def, definition of rule
        # et, token at the head of T
        #
        # Init : length(T) > 0
        #        length(S) = 0
        #        length(E) = 0
        # Next : T' = T - et
        #        when r_def.terminal?
        #          when match(r_def.name, et)
        #            S = match(r_def, et)
        #          otherwise
        #            E' = E + et
        #        when r_def.alternation?
        #          when match_any(r_def, T)
        #            S' = match_any(r_def, T)
        #          otherwise
        #            E' = E + et
        #        when r_def.concatenation?
        #          when match_and_then(r_def, T)
        #            S' = match_and_then(r_def, T)
        #          otherwise
        #            E' = E + et
        #        when r_def.option?
        #          when match_one(r_def, T)
        #            S' = match_one(r_def, T)
        #          otherwise
        #            S' = match_none(r_def, T)
        #          otherwise
        #            E' = E + et
        #        when r_def.repetition?
        #          when match_many(r_def, T)
        #            S' = match_many(r_def, T)
        #          otherwise
        #            S' = match_none(r_def, T)
        #          otherwise
        #            E' = E + et
        def parse(tokens, rules)
          if terminal?
            parse_terminal(tokens)
          elsif alternation_rule?
            parse_any(tokens, rules)
          elsif concatenation_rule?
            parse_and_then(tokens, rules)
          elsif option_rule?
            parse_maybe(tokens, rules)
          elsif repetition_rule?
            parse_many(tokens, rules)
          end
        end

        #Return a Token sequence with one Token that is an instance of
        #  a terminal rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        def parse_terminal(tokens)
          lookahead = tokens.first
          if @name == lookahead.name
            return build_parse_result([lookahead], tokens.drop(1))
          else
            raise ParseError, parse_terminal_error_message(@name, lookahead.name)
          end
        end

        def build_parse_result(parsed_seq, rest)
          if parsed_seq.instance_of? Array
            parsed_seq = Eson::Tokenizer::TokenSeq.new(parsed_seq)
          elsif rest.instance_of? Array
            rest = Eson::Tokenizer::TokenSeq.new(rest)
          end
          result = {:parsed_seq => parsed_seq, :rest => rest}
        end

        def parse_terminal_error_message(expected_token, actual_token)
          "Expected a symbol of type :#{expected_token} but got a :#{actual_token} instead."
        end

        #Return a Token sequence that is a legal instance of
        #  an alternation rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        #@eskimobear.specification
        # T, input token sequence
        # et, token at the head of T
        # r_def, list of terms in rule   
        # S, sub-sequence matching rule
        # E, sequence of error tokens
        #
        # Init : length(T) > 0
        #        length(E) = 0
        #        length(S) = 0
        # Next : r_term = match_first(r_def, et)
        #        when r_term.terminal?
        #            S' = S + et
        #            T' = T - et
        #        when r_term.nonterminal?
        #          when r_term.can_parse?(r_def, T)
        #            S' = r_term.parse(r_def, T)
        #            T' = T - S'
        #            r_def' = []
        #        otherwise
        #          E + et 
        def parse_any(tokens, rules)
          lookahead = tokens.first
          if matched_any_first_sets?(lookahead, rules)
            term = first_set_match(lookahead, rules)
            if term.instance_of? Terminal
              return build_parse_result([lookahead], tokens.drop(1))
            else
              rule = rules.get_rule(term.rule_name)
              return rule.parse(tokens, rules)
            end
          end
          raise ParseError, parse_terminal_error_message(@name, lookahead.name)
        end

        #@param token [Eson::Tokenizer::Token] token
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Boolean] true if token is part of the first set of any
        #  of the rule's terms.
        def matched_any_first_sets?(token, rules)
          terms = get_matching_first_sets(token, rules)
          terms.length.eql?(1)
        end
        
        def get_matching_first_sets(token, rules)
          @ebnf.term_set.find_all do |i|
            rule = rules.get_rule(i.rule_name)
            rule.first_set.include? token.name
          end
        end
        
        #@param token [Eson::Tokenizer::Token] token
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Terminal, NonTerminal] term that has a first_set
        #  which includes the given token. Works with alternation rules only.
        #@raise [JointFirstSetError] if more than one term found
        #@raise [UnmatchedFirstSetError] if no terms found
        def first_set_match(token, rules)
          terms = get_matching_first_sets(token, rules)
          case terms.length
          when 1
            terms.first
          when 0
            raise UnmatchedFirstSetError,
                  "None of the first_sets of #{@name} contain #{token.name}"
          else
            raise JointFirstSetError,
                  "The first_sets of #{@name} are not disjoint."
          end
        end

        #Return a Token sequence that is a legal instance of
        #  a concatenation rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        #@eskimobear.specification
        # T, input token sequence
        # et, token at the head of T
        # r_def, list of terms in rule
        # r_term, term at the head of r_def      
        # S, sub-sequence matching rule
        # E, sequence of error tokens
        #
        # Init : length(T) > 0
        #        length(E) = 0
        #        length(S) = 0
        # Next : r_def, et
        #        when r_def = []
        #          S
        #        when r_term.terminal?
        #          when match_terminal(r_term, et)
        #            S' = S + et
        #            T' = T - et
        #            r_def' = r_def - r_term
        #          otherwise
        #            E + et
        #        when r_term.nonterminal?
        #          when can_parse?(r_def, T)
        #            S' = parse(r_def, T)
        #            T' = T - S'
        #          otherwise
        #            E + et
        def parse_and_then(tokens, rules)
          result = build_parse_result([], tokens)
          @ebnf.term_list.each_with_object(result) do |i, acc|
            rule = rules.get_rule(i.rule_name)
            parse_result = rule.parse(acc[:rest], rules)
            acc[:parsed_seq].concat(parse_result[:parsed_seq])
            acc[:rest] = parse_result[:rest]
          end
        end

        #Return a Token sequence that is a legal instance of
        #  an option rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        #@eskimobear.specification
        # T, input token sequence
        # et, token at the head of T
        # r, the option rule
        # r_term, single term of the rule
        # S, sub-sequence matching rule
        # E, sequence of error tokens
        #
        # Init : length(T) > 0
        #        length(E) = 0
        #        length(S) = 0
        # Next : r_term, et
        #        when r_term.terminal?
        #          when match(r_term, et)
        #            S = et
        #            T - et
        #        when r_term.nonterminal?
        #           S = parse(r, T)
        #           T - S
        #        when match_follow_set?(r, et)
        #           S = []
        #           T
        #        otherwise
        #          E + et
        def parse_maybe(tokens, rules)
          term = @ebnf.term
          term_rule = rules.get_rule(term.rule_name)
          begin 
            term_rule.parse(tokens, rules)
          rescue ParseError => pe
            parse_none(tokens, pe)
          end
        end

        def parse_none(tokens, exception)
          lookahead = tokens.first
          if @follow_set.include? lookahead.name
            return build_parse_result([], tokens)
          else
            raise exception
          end
        end

        #Return a Token sequence that is a legal instance of
        #  a repetition rule
        #@param tokens [Eson::Tokenizer::TokenSeq] a token sequence
        #@param rules [Eson::Language::RuleSeq] list of possible rules
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        #@eskimobear.specification
        # T, input token sequence
        # et, token at the head of T
        # r, the option rule
        # r_term, single term of the rule
        # S, sub-sequence matching rule
        # E, sequence of error tokens
        #
        # Init : length(T) > 0
        #        length(E) = 0
        #        length(S) = 0
        # Next : r_term, et
        #        S' = S + match_maybe(r_term, T)
        #        T' = T - S'
        #        when S = []
        #          S, T
        #        when T = []
        #          S, T
        #        otherwise
        #          E + et
        def parse_many(tokens, rules)
          acc = parse_maybe(tokens, rules)
          is_tokens_empty = acc[:rest].empty?
          is_rule_nulled = acc[:parsed_seq].empty?
          if is_tokens_empty || is_rule_nulled
            acc
          else
            begin
              acc.merge(parse_many(acc[:rest], rules)) do |key, old, new|
                case key
                when :parsed_seq
                  old.concat(new)
                when :rest
                  new
                end
              end
            rescue ParseError => pe
              acc
            end
          end
        end

        #Compute the start rxp of nonterminal rules
        #@param rules [Eson::Language::RuleSeq] the other rules making
        #  up the formal language
        #@return [Eson::Language::RuleSeq::Rule] the mutated Rule
        def compute_start_rxp(rules)
          @start_rxp = if alternation_rule?
                         make_alternation_rxp(rules, term_names)
                       elsif concatenation_rule?
                         make_concatenation_rxp(rules, term_names)
                       elsif repetition_rule?
                         make_repetition_rxp(rules, term_names)
                       elsif option_rule?
                         make_option_rxp(rules, term_names)
                       end
          self
        end
        
        def make_option_rxp(rules, rule_names)
          make_repetition_rxp(rules, rule_names)
        end

        def make_repetition_rxp(rules, rule_names)
          rules.get_rule(rule_names.first).rxp
        end
        
        def make_concatenation_rxp(rules, rule_names)
          rxp_strings = get_rxp_sources(rules, rule_names)
          combination = rxp_strings.reduce("") do |memo, i|
            memo.concat(i)
          end
          apply_at_start(Regexp.new(combination))
        end

        def make_alternation_rxp(rules, rule_names)
          rxp_strings = get_rxp_sources(rules, rule_names)
          initial = rxp_strings.first
          rest = rxp_strings.drop(1)
          combination = rest.reduce(initial) do |memo, i|
            memo.concat("|").concat(i)
          end
          apply_at_start(Regexp.new(combination))
        end

        def get_rxp_sources(rules, rule_array)
          rule_array.map do |i|
            rules.get_rule(i).rxp.source
          end
        end
      end    
      # end of rule
      
      def self.new(obj)
        array = super
        unless self.all_rules?(array)
          raise ItemError, self.new_item_error_message
        end
        array
      end

      def self.new_item_error_message
        "One or more of the given array elements are not of the type Eson::Language::RuleSeq::Rule"
      end

      def make_terminal_rule(new_rule_name, rxp)
        self.push(Rule.new_terminal_rule(new_rule_name, rxp))
      end

      def convert_to_terminal(rule_name)
        if partial_rule?(rule_name)
          raise ConversionError, rule_conversion_error_message(rule_name)
        elsif !include_rule?(rule_name)
          raise ItemError, missing_item_error_message(rule_name)
        end
        self.map! do |rule|
          new_rule = if rule_name == rule.name
                         Rule.new_terminal_rule(rule.name, rule.rxp)
                     else
                       rule
                     end
          new_rule
        end
      end

      def rule_conversion_error_message(rule_name)
        "The Rule #{rule_name} has partial status and thus has an undefined regular expression. This Rule cannot be converted to a terminal Rule."
      end
        
      def partial_rule?(rule_name)
        self.get_rule(rule_name).partial_status
      end

      #Create a non-terminal production rule that is a concatenation
      #of terminals and non-terminals
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_names [Array<Symbol>] sequence of the terms in
      #  the rule given in order
      def make_concatenation_rule(new_rule_name, rule_names)
        partial_status = include_rules?(rule_names) ? false : true
        first_rule_name = rule_names.first
        inherited_partial_status = if include_rule?(first_rule_name)
                                     get_rule(first_rule_name).partial_status
                                   else
                                     true
                                   end
        partial_status = inherited_partial_status || partial_status
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        partial_status,
                        ebnf_concat(rule_names))
        prepare_first_set(rule)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_concat(rule_names)
        term_list = rule_names.map do |i|
          rule_to_term(i)
        end
        EBNF::ConcatenationRule.new(term_list)
      end

      def rule_to_term(rule_name)
        if self.include_rule? rule_name
          rule = get_rule(rule_name)
          if rule.terminal?
            EBNF::Terminal.new(rule_name)
          else
            EBNF::NonTerminal.new(rule_name)
          end
        else
          EBNF::NonTerminal.new(rule_name)
        end
      end

      #@param rule [Eson::Language::RuleSeq::Rule] Given rule
      def prepare_first_set(rule)
        unless rule.partial_status
          build_first_set(rule)
        end
        if rule.option_rule? || rule.repetition_rule?
          rule.first_set.push :nullable
        end
      end

      #Create a non-terminal production rule that is an alternation
      # of terminals and non-terminals
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_names [Array<Symbol>] the terms in the rule
      def make_alternation_rule(new_rule_name, rule_names)
        partial_status = include_rules?(rule_names) ? false : true
        inherited_partial_status = rule_names.any? do |i|
          include_rule?(i) ? get_rule(i).partial_status : true
        end
        partial_status = inherited_partial_status || partial_status
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        partial_status,
                        ebnf_alt(rule_names))
        prepare_first_set(rule)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_alt(rule_names)
        term_list = rule_names.map do |i|
          rule_to_term(i)
        end
        EBNF::AlternationRule.new(term_list)
      end

      #Create a non-terminal production rule of either a non-terminal
      #  or terminal
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_name [Array<Symbol>] the single term in the rule
      def make_repetition_rule(new_rule_name, rule_name)
        partial_status = if include_rule?(rule_name)
                           get_rule(rule_name).partial_status
                         else
                           true
                         end
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        partial_status,
                        ebnf_rep(rule_name))
        prepare_first_set(rule)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_rep(rule_name)
        EBNF::RepetitionRule.new(rule_to_term(rule_name)) 
      end

      #Create a non-terminal production rule of either a non-terminal
      #  or terminal
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_name [Array<Symbol>] the single term in the rule 
      def make_option_rule(new_rule_name, rule_name)
        partial_status = if include_rule?(rule_name)
                           get_rule(rule_name).partial_status
                         else
                           true
                         end
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        partial_status,
                        ebnf_opt(rule_name))
        prepare_first_set(rule)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_opt(rule_name)
        EBNF::OptionRule.new(rule_to_term(rule_name))
      end
      
      def missing_items_error_message(rule_names)
        names = rule_names.map{|i| ":".concat(i.to_s)}
        "One or more of the following Eson::Language::Rule.name's are not present in the sequence: #{names.join(", ")}."
      end

      def include_rules?(rule_names)
        rule_names.all?{ |i| include_rule? i }
      end

      def include_rule?(rule_name)
        if rule_name.is_a? String
          names.include? rule_name.intern
        elsif rule_name.is_a? Symbol
          names.include? rule_name
        else
          false
        end
      end

      def names
        self.map{|i| i.name}
      end
      
      def get_rule(rule_name)
        unless include_rule?(rule_name)
          raise ItemError, missing_item_error_message(rule_name)
        end
        self.find{|i| i.name == rule_name}
      end

      def missing_item_error_message(rule_name)
        "The Eson::Language::Rule.name ':#{rule_name}' is not present in the sequence."
      end
      
      def remove_rules(rule_names)
        if include_rules?(rule_names)
          initialize(self.reject{|i| rule_names.include?(i.name)})
        else
          nil
        end
      end

      def build_language(lang_name, top_rule_name=nil)
        rules = self.clone
        result_lang = Struct.new lang_name, *rules.names do
          include LanguageOperations
        end
        complete_partial_first_sets(rules)
        compute_follow_sets(rules, top_rule_name)
        lang = result_lang.new *rules
        if top_rule_name.nil?
          lang
        else
          lang.make_top_rule(top_rule_name)
        end
      end

      def complete_partial_first_sets(rules)
        rules.each do |rule|
          if rule.partial_status
            build_first_set(rule)
            rule.partial_status = false
          end
        end
        rules
      end

      #Compute and set the first_set for a rule. The first_set is the
      #set of terminal names that can legally  appear at the start of
      #the sequences of symbols derivable from a rule. The first_set
      #of a terminal rule is the rule name.
      #@param rule [Eson::Language::RuleSeq::Rule] Given rule
      #@eskimobear.specification
      #
      #Prop : The first set of a concatenation is the first set of the
      #       first terms of the rule which are nullable. If all the terms
      #       are nullable then the first set should include :nullable.
      #     : The first set of an alternation is the first set of all of it's
      #       terms combined.
      #     : The first set of an option or repetition is the first set of
      #       it's single term with :nullable included.
      def build_first_set(rule)
        terms = rule.term_names
        set = if rule.concatenation_rule?
                first_nullable_terms = terms.take_while do |term|
                  get_rule(term).nullable?
                end
                if first_nullable_terms.empty?
                  get_first_set(get_rule(terms.first))
                else
                  first_set = first_nullable_terms.each_with_object([]) do |term, acc|
                    acc.concat(get_first_set(get_rule(term)))
                  end
                  first_set.delete(:nullable)
                  if first_nullable_terms.length < terms.length
                    additional_term = terms[first_nullable_terms.length]
                    additional_first_set = get_first_set(get_rule(additional_term))
                    first_set.concat(additional_first_set)
                  elsif first_nullable_terms.length == terms.length
                    first_set.push(:nullable)
                  end
                  first_set.uniq
                end
              elsif rule.alternation_rule?
                terms.each_with_object([]) do |term, acc|
                  first_set = get_first_set(get_rule(term))
                  acc.concat(first_set)
                end
              elsif rule.repetition_rule?
                get_first_set(get_rule(terms.first))
              elsif rule.option_rule?
                get_first_set(get_rule(terms.first))
              end
        rule.first_set.concat set
      end

      #Ensure a first_set is completed before returning. Prevents
      #  complications due to ordering of Rules in the RuleSeq. 
      #@param rule [Eson::Language::RuleSeq::Rule] Given rule
      #@return [Array<Symbol>] first set
      def get_first_set(rule)
        if rule.partial_status
          build_first_set(rule)
        end
        rule.first_set
      end
      
      #Compute the follow_set of rules. The follow_set is
      #the set of terminals that can appear to the right of the rule.
      #@param rules [Eson::Language::RuleSeq] list of possible rules
      #@param top_rule_name [Symbol] name of the top rule in the language
      #  from which @rules derives.
      def compute_follow_sets(rules, top_rule_name=nil)
        unless top_rule_name.nil?
          top_rule = rules.get_rule(top_rule_name)
          add_to_follow_set(top_rule, :eof)
        end
        map = build_follow_dep_graph(rules)
        map[1..-1].each do |stage|
          stage.each do |tuple|
            rule = rules.get_rule(tuple[:term])
            #add first_set from first_set rules
            tuple[:first_set_rules].each do |r|
              add_to_follow_set(rule, r.first_set-[:nullable])
            end
            #add follow_set from follow_set rules
            tuple[:follow_set_rules].each do |r|
              add_to_follow_set(rule, r.follow_set)
            end
          end
        end
      end

      #Builds a dependency graph for computing follow sets. This
      #ensures that follow sets are computed in the correct order.      
      #@return [Array] Array of array of tuples. Each tuple has a :term,
      #  and optional :first_set_rules and :follow_set_rules arrays
      def build_follow_dep_graph(rules)
        dep_graph = rules.map do |rule|
          tuple = {:term => rule.name}
          concat_rules = rules.select{|i| i.concatenation_rule?}
                         .select{|i| i.term_names.include? rule.name}
          if concat_rules
            tuple[:dep_rules] = concat_rules
          end
          tuple                             
        end.partition do |t|
          t[:dep_rules].nil?
        end
        #transform :dep_rules to :first_set_rules and :follow_set_rules
        #:first_set_rules are those rules which must have their first_set
        #added to the term's follow_set
        #:follow_set_rules are those rules which must have their follow_set
        #added to the term's follow_set
        dep_graph.last.each do |t|
          t[:first_set_rules] = []
          t[:follow_set_rules] = []
          t[:dep_rules].each do |rule|
            term_seq = rule.term_names
            last_position = term_seq.size - 1 
            term_position = term_seq.index(t[:term])
            last_nullable_terms = term_seq.reverse.take_while do |i|
              rules.get_rule(i).nullable?
            end
            if last_nullable_terms.empty?
              #no nullable terms at end of sequence         
              if last_position == term_position
                #add rule to follow set if term is last term
                #protect against left recursive references
                unless rule.name == t[:term]
                  t[:follow_set_rules].push(rule)
                end
              else
                #get term after the term and add this first set   
                term_after = term_seq[term_position + 1]
                t[:first_set_rules].push(rules.get_rule(term_after))
              end
            else
              if last_nullable_terms.include? t[:term]
                #add rule to follow set
                #protect against left recursive references
                unless rule.name == t[:term]
                  t[:follow_set_rules].push(rule)
                end
              else
                term_after = term_seq[term_position + 1]
                t[:first_set_rules].push(rules.get_rule(term_after))
              end
            end
            t.delete(:dep_rules)
          end
        end

        last_stage = dep_graph.last.partition do |t|
          t[:follow_set_rules].empty?
        end
        dep_graph[0...-1].concat last_stage
      end
 
      def add_to_follow_set(rule, term_name)
        if term_name.instance_of? Array
          rule.follow_set.concat(term_name)
        else
          rule.follow_set.push(term_name)
        end
      end
      
      protected
      
      def self.all_rules?(seq)
        seq.all? {|i| i.class == Rule }
      end
    end
  end
end
