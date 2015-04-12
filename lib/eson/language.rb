require 'forwardable'
require 'pry'
require_relative './lexeme_capture.rb'
require_relative './ebnf.rb'

module Eson

  module Language
    
    extend self
    
    class RuleSeq < Array

      WrongElementType = Class.new(StandardError)
      MissingRule = Class.new(StandardError)
      CannotMakeTerminal = Class.new(StandardError)

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
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
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
        def parse(tokens, rules, tree=nil)
          if terminal?
            acc = parse_terminal(tokens, tree)
          else
            if tree.nil?
              tree = AbstractSyntaxTree.new
            end
            tree.insert(self)
            acc = if alternation_rule?
                    parse_any(tokens, rules, tree)
                  elsif concatenation_rule?
                    parse_and_then(tokens, rules, tree)
                  elsif option_rule?
                    parse_maybe(tokens, rules, tree)
                  elsif repetition_rule?
                    parse_many(tokens, rules, tree)
                  end
            acc[:tree].close_active
            acc
          end
        end

        #Return a Token sequence with one Token that is an instance of
        #  a terminal rule
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
        #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
        #  tokens as :parsed_seq and the rest of the Token sequence as :rest
        #@raise [ParseError] if no legal sub-sequence can be found
        def parse_terminal(tokens, tree)         
          lookahead = tokens.first
          if @name == lookahead.name
            leaf = AbstractSyntaxTree.new(lookahead)
            tree = if tree.nil?
                     leaf
                   else
                     tree.merge(leaf)
                   end
            build_parse_result([lookahead], tokens.drop(1), tree)
          else
            raise ParseError, parse_terminal_error_message(@name, lookahead, tokens)
          end
        end

        def build_parse_result(parsed_seq, rest, tree)
          if parsed_seq.instance_of? Array
            parsed_seq = Eson::TokenPass::TokenSeq.new(parsed_seq)
          elsif rest.instance_of? Array
            rest = Eson::TokenPass::TokenSeq.new(rest)
          end
          result = {:parsed_seq => parsed_seq, :rest => rest, :tree => tree}
        end

        def parse_terminal_error_message(expected_token, actual_token, token_seq)
          "Error while parsing #{@name}. Expected a symbol of type :#{expected_token} but got a :#{actual_token.name} instead in line #{actual_token.line_number}:\n #{actual_token.line_number}. #{token_seq.get_program_line(actual_token.line_number)}\n"
        end

        #Return a Token sequence that is a legal instance of
        #  an alternation rule
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
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
        def parse_any(tokens, rules, tree)
          lookahead = tokens.first
          if matched_any_first_sets?(lookahead, rules)
            term = first_set_match(lookahead, rules)
            rule = rules.get_rule(term.rule_name)
            t = rule.parse(tokens, rules, tree)
            return t
          end
          raise ParseError, parse_terminal_error_message(@name, lookahead, tokens)
        end

        #@param token [Eson::Language::LexemeCapture::Token] token
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
        
        #@param token [Eson::Language::LexemeCapture::Token] token
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
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
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
        def parse_and_then(tokens, rules, tree)
          result = build_parse_result([], tokens, tree)
          @ebnf.term_list.each_with_object(result) do |i, acc|
            rule = rules.get_rule(i.rule_name)
            parse_result = rule.parse(acc[:rest], rules, acc[:tree])
            acc[:parsed_seq].concat(parse_result[:parsed_seq])
            acc[:rest] = parse_result[:rest]
          end
        end

        #Return a Token sequence that is a legal instance of
        #  an option rule
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
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
        def parse_maybe(tokens, rules, tree)
          term = @ebnf.term
          term_rule = rules.get_rule(term.rule_name)
          begin
            acc = term_rule.parse(tokens, rules)
            acc.store(:tree, tree.merge(acc[:tree]))
            acc
          rescue ParseError => pe
            parse_none(tokens, pe, tree)
          end
        end

        def parse_none(tokens, exception, tree)
          lookahead = tokens.first
          if @follow_set.include? lookahead.name
            return build_parse_result([], tokens, tree)
          else
            raise exception
          end
        end

        #Return a Token sequence that is a legal instance of
        #  a repetition rule
        #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
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
        def parse_many(tokens, rules, tree)
          acc = parse_maybe(tokens, rules, tree)
          is_tokens_empty = acc[:rest].empty?
          is_rule_nulled = acc[:parsed_seq].empty?
          if is_tokens_empty || is_rule_nulled
            acc
          else
            begin
              acc.merge(parse_many(acc[:rest], rules, acc[:tree])) do |key, old, new|
                case key
                when :parsed_seq
                  old.concat(new)
                when :rest, :tree
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

      #Hook to ensure that RuleSeq can only be initialized
      #with an array of Rules.
      #@param obj [Array]
      #@return [Eson::Language]
      def self.new(obj)
        array = super
        unless self.all_rules?(array)
          raise WrongElementType, self.new_item_error_message
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
          raise CannotMakeTerminal, rule_conversion_error_message(rule_name)
        elsif !include_rule?(rule_name)
          raise MissingRule, missing_rule_error_message(rule_name)
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
        "The Rule #{rule_name} has partial status thus it has an undefined regular expression. This Rule cannot be converted to a terminal Rule because it can't capture tokens."
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

      #@param rule [Eson::Language::RuleSeq::Rule]
      #@return [nil]
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
          raise MissingRule, missing_rule_error_message(rule_name)
        end
        self.find{|i| i.name == rule_name}
      end

      def missing_rule_error_message(rule_name)
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

      #Ensure a first_set is completed before returning it. Prevents
      #  complications due to ordering of Rules in the RuleSeq. 
      #@param rule [Eson::Language::RuleSeq::Rule] Given rule
      #@return [Array<Symbol>] first set
      def get_first_set(rule)
        if rule.partial_status
          build_first_set(rule)
        end
        rule.first_set
      end
      
      #Compute the follow_set of nonterminal rules. The follow_set is
      #the set of terminals that can appear to the right of a nonterminal
      #in a sentence.
      #@param rules [Eson::Language::RuleSeq] list of possible rules
      #@param top_rule_name [Symbol] name of the top rule in the language
      #  from which @rules derives.
      def compute_follow_sets(rules, top_rule_name=nil)
        unless top_rule_name.nil?
          top_rule = rules.get_rule(top_rule_name)
          add_to_follow_set(top_rule, :eof)
        end
        dependency_graph = build_follow_dep_graph(rules)
        dependency_graph.each do |stage|
          stage.each do |tuple|
            rule = rules.get_rule(tuple[:term])
            tuple[:first_set_deps].each do |r|
              add_to_follow_set(rule, r.first_set-[:nullable])
            end
            tuple[:follow_set_deps].each do |r|
              add_to_follow_set(rule, r.follow_set)
            end
          end
        end
      end

      #Builds a dependency graph for computing :follow_set's. This
      #returns tuples which pairs each term with it's dependencies
      #for follow_set computation. Dependencies are divided into
      #:first_set_deps and :follow_set_deps. The tuples are divided
      #into stages to ensure that follow sets are computed in the
      #correct order. Stage 1 contains rules with no dependencies.
      #Stage 2 contains rules with :first_set_deps only. Stage 3 and
      #upwards contains rules with :follow_set_deps from stages 
      #before it only.
      #@return [Array] Array of array of tuples. Each tuple has a :term,
      #  and optional :first_set_deps and :follow_set_deps arrays
      def build_follow_dep_graph(rules)
        dep_graph = rules.map do |rule|
          dependency_rules = rules.select{|i| i.nonterminal?&&!i.alternation_rule?}
                             .select{|i| i.term_names.include? rule.name}
          tuple = {:term => rule.name,
                   :dependencies => dependency_rules,
                   :first_set_deps => [],
                   :follow_set_deps => []}
        end
        dep_graph = dep_graph.partition do |t|
          t[:dependencies].empty?
        end

        #Replace :dependencies with :first_set_deps and :follow_set_deps
        #:first_set_deps are those rules which must have their first_set
        #added to the term's follow_set. :follow_set_deps are those rules
        #which must have their follow_set added to the term's follow_set
        dep_graph.last.each do |t|
          t[:dependencies].each do |dep_rule|
            term_list = dep_rule.term_names 
            term_position = term_list.index(t[:term])
            nullable_last = term_list.reverse.take_while do |i|
              rules.get_rule(i).nullable?
            end
            term_is_last = term_position == term_list.size - 1 
            if term_is_last || nullable_last.include?(t[:term])          
              unless dep_rule.name == t[:term]
                t[:follow_set_deps].push(dep_rule)
              end
            else
              term_after = term_list[term_position + 1]
              t[:first_set_deps].push(rules.get_rule(term_after))
            end
          end
        end

        empty_and_filled_follow_set_stages = dep_graph.last.partition do |t|
          t[:follow_set_deps].empty?
        end
        dep_graph = dep_graph[0...-1].concat empty_and_filled_follow_set_stages
        
        no_stage_deps_and_otherwise = split_by_follow_set_dep_order(empty_and_filled_follow_set_stages.last)        
        dep_graph = dep_graph[0...-1].concat no_stage_deps_and_otherwise
      end

      #Split a `stage` of tuples into an array of stages such that members
      #of a stage contain follow_set_deps of terms which appear in
      #previous stages. This ensures that the dependencies are ordered.
      #@param stage [Array<tuple>]
      #@return [Array<<Array<tuple>>]
      def split_by_follow_set_dep_order(stage, acc=[])
        all_terms = stage.flat_map{|t| t[:term]}
        final_stages = stage.partition do |t|
          t[:follow_set_deps].none?{|fs| all_terms.include?(fs.name)}
        end
        last_stage = final_stages.last
        acc = acc[0...-1].concat final_stages
        if last_stage.empty?
          acc
        else
          split_by_follow_set_dep_order(last_stage, acc)
        end
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

    class AbstractSyntaxTree    
      InsertionError = Class.new(StandardError)
      ClosedTreeError = Class.new(StandardError)
      ChildInsertionError = Class.new(StandardError)
      InitializationError = Class.new(StandardError)

      extend Forwardable

      Token = Eson::Language::LexemeCapture::Token
      Rule = Eson::Language::RuleSeq::Rule

      attr_reader :height

      #Initialize tree with obj as root node. An empty
      #tree is created if no parameter is given.
      #@param obj [Eson::Language::RuleSeq::Rule] Rule
      #@raise [InsertionError] obj is not a valid type
      #for the root node
      def initialize(obj=nil)
        insert_root(obj)
      rescue InsertionError => e
        raise InitializationError,
              not_a_valid_root_error_message(obj)
      end

      def insert_root(obj)
        if obj.nil?
          @root_tree = @active = nil
        elsif obj.instance_of? Token
          @root_tree = @active = make_leaf(obj)
          @height = 1
          close_active
        elsif obj.instance_of?(Rule) && obj.nonterminal?
          @root_tree = @active = make_tree(obj)
          @height = 1
        else
          raise InsertionError, not_a_valid_input_error_message(obj)
        end
      end
      
      def make_tree(rule)
        tree = Tree.new(rule, TreeSeq.new, active_node, true)
               .set_level
      end
      
      def make_leaf(token)
        tree = Tree.new(token, nil, active_node, false)
               .set_level
      end
      
      def not_a_valid_root_error_message(obj)
        "The class #{obj.class} of '#{obj}' cannot be used as a root node for #{self.class}. Parameter must be either a #{Token} or a nonterminal #{Rule}."
      end

      def empty?
        @root_tree.nil?
      end
      
      #Insert an object into the active tree node. Tokens are
      #added as leaf nodes and Rules are added as the active tree
      #node.
      #@param obj [Token, Rule] eson token or production rule
      #@raise [InsertionError] If obj is neither a Token or Rule
      #@raise [ClosedTreeError] If the tree is closed
      def insert(obj)
        if empty?
          insert_root(obj)
        else
          ensure_open
          if obj.instance_of? Token
            insert_leaf(obj)
          elsif obj.instance_of? Rule
            insert_tree(obj)
          else
            raise InsertionError, not_a_valid_input_error_message(obj)
          end
        end
        self
      end
      
      def insert_leaf(token)
        leaf = make_leaf(token)
        active_node.children.push leaf
        update_height(leaf) 
      end

      def update_height(tree)
        if tree.level > @height
          @height = tree.level
        end
      end

      def insert_tree(rule)
        tree = make_tree(rule)
        active_node.children.push tree
        update_height(tree)
        @active = tree
      end

      def not_a_valid_input_error_message(obj)
        "The class #{obj.class} of '#{obj}' is not a valid input for the #{self.class}. Input must be a #{Token}."
      end

      #Add a given tree to this tree's active node
      #@param tree [Eson::Language::AbstractSyntaxTree]
      #@raise [MergeError] if tree is not closed before merging
      def merge(tree)
        if tree.closed?
          tree.get.increment_levels(active_node.level)
          possible_height = tree.height + active_node.level
          @height = @height < possible_height ? possible_height : @height
          @active.children.push(tree.get)
          self
        end
      end
      
      #Get the active node of the tree. This is the open tree node to
      #the bottom right of the tree i.e. the last inserted tree node.
      #@return [Eson::Language::AbstractSyntaxTree::Tree] the active tree node
      def active_node
        @active
      end

      def get
        @root_tree
      end

      def close_tree
        @root_tree.open_state = false
        self
      end

      #Closes the active node of the tree and makes the next
      #open ancestor the active node.  
      #@return [Eson::Language::AbstractSyntaxTree]
      def close_active
        new_active = @active.parent
        @active.close
        unless new_active.nil?
          @active = new_active
        end
        self
      end

      def_delegators :@root_tree, :root_value, :degree, :closed?, :open?, :leaf?,
                     :ensure_open, :has_child?, :has_children?, :rule, :children, :level
      
      #Struct class for a tree node
      Tree = Struct.new :value, :children, :parent, :open_state, :level do

        #The value of the root node
        #@return [Eson::Language::RuleSeq::Rule]
        def root_value
          value
        end
        
        #Close the active node of the tree and make parent active.
        def close
          self.open_state = false
        end
      
        #The open state of the tree. 
        #@return [Boolean]
        def open?
          open_state
        end

        def closed?
          !open?
        end

        def degree
          children.length
        end

        def leaf?
          children.nil? || children.empty?
        end

        def ensure_open
          if closed?
            raise ClosedTreeError, closed_tree_error_message
          end
        end
        
        def closed_tree_error_message
          "The method `#{caller_locations(3).first.label}' is not allowed on a closed tree."
        end

        #@param name [Symbol] name of child node
        def has_child?(name)
          children.detect{|i| i.value.name == name} ? true : false
        end

        #@param names [Array<Symbol>] ordered list of the names of child nodes
        def has_children?(names)
          names == children.map{|i| i.value.name}
        end

        #@param offset [Integer]
        def set_level(offset=0)
          self.level = parent.nil? ? 1 : 1 + parent.level
          self.level = level + offset
          self
        end

        #Increment the tree levels of a given tree
        #@param offset [Integer]
        def increment_levels(offset)
          set_level(offset)
          unless leaf?
            children.each{|t| t.set_level}
          end
        end
      end

      class TreeSeq < Array

        Tree = Eson::Language::AbstractSyntaxTree::Tree
        
        pushvalidate = Module.new do
          def push(obj)
            if obj.instance_of? Tree
              super
            else
              raise ChildInsertionError, not_a_valid_node_error_message(obj)
            end
          end
        end

        prepend pushvalidate

        def not_a_valid_node_error_message(obj)
          "The class #{obj.class} of '#{obj}' is not a valid node for the #{self.class}. The object must be a #{Tree}."
        end
      end
    end
  end
end
