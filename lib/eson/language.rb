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

      #Test if a Token is an instance of a Terminal
      #@param terminal [Terminal]
      #@param token [Eson::Tokenizer::TokenSeq::Token] a token
      #@return [Boolean] true if the Terminal's rule_name matches
      #  the token name
      def accept_terminal?(terminal, token)
        if terminal.instance_of? Terminal
          terminal.rule_name == token.name
        else
          false
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

        ParseError = Class.new(StandardError)
        UnmatchedFirstSetError = Class.new(StandardError)
        JointFirstSetError = Class.new(StandardError)

        attr_accessor :name, :first_set, :partial_status, :ebnf

        #@param name [Symbol] name of the production rule
        #@param sequence [Array<Terminal, NonTerminal>] list of terms this
        #  rule references, this list is empty when the rule is a terminal
        #@param start_rxp [Regexp] regexp that accepts valid symbols for this
        #  rule
        #@param first_set [Array<Symbol>] the set of terminals that can legally
        #  appear at the start of the sequences of symbols derivable from
        #  this rule. The first set of a terminal is the rule name. Any rule that
        #  has terms marked as recursive generates a partial first set; the
        #  full first set is computed when a formal language is built using the
        #  rule.
        #@param partial_status [Boolean] true if any terms are undefined or descend
        #   from an undefined term.
        #@param ebnf [Eson::EBNF] ebnf definition of the rule, each defintion
        #  contains only one control, thus a rule can be one of the four control
        #  types:- concatenation, alternation, repetition and option.
        def initialize(name, start_rxp=nil, first_set=nil, partial_status=nil, ebnf=nil)
          @name = name
          @ebnf = ebnf
          @start_rxp = start_rxp
          @first_set = terminal? ? [name] : first_set
          @partial_status = terminal? ? false : partial_status
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
          @ebnf.term_list.each_with_object(result) do |i, a|
            if i.instance_of? Terminal
              lookahead = a[:rest].first
              if accept_terminal?(i, lookahead)
                a[:parsed_seq].push(lookahead)
                a[:rest] = a[:rest].drop(1)
              else
                raise ParseError, parse_terminal_error_message(i.rule_name, lookahead.name)
              end
            elsif i.instance_of? NonTerminal
              rule = rules.get_rule(i.rule_name)
              parsed_seq = rule.parse(a[:rest], rules)[:parsed_seq]
              a[:parsed_seq].concat(parsed_seq)
              a[:rest] = a[:rest].drop(parsed_seq.length)
            end
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
          if term.instance_of? Terminal
            lookahead = tokens.first
            if accept_terminal?(term, lookahead)
              return build_parse_result([lookahead], tokens.drop(1))
            end
          elsif term.instance_of? NonTerminal
            rule = rules.get_rule(term.rule_name)
            rule.parse(tokens, rules)
          end
        end

        def match(string)
          string.match(self.rxp)
        end

        def rxp
          @start_rxp
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
      #@eskimobear.specification
      # Prop: The first set of is the first set of the first term
      #       of the rule definition
      def make_concatenation_rule(new_rule_name, rule_names)
        partial_status = include_rules?(rule_names) ? false : true
        first_rule_name = rule_names.first
        inherited_partial_status = if include_rule?(first_rule_name)
                                     get_rule(first_rule_name).partial_status
                                   else
                                     true
                                   end
        partial_status = inherited_partial_status || partial_status
        ebnf = ebnf_concat(rule_names)
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        first_set_concat(ebnf, partial_status),
                        partial_status,
                        ebnf)
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

      def first_set_concat(ebnf, partial_status)
        first = ebnf.term_list.first
        if partial_status
          []
        else
          get_rule(first.rule_name).first_set
        end
      end

      #Create a non-terminal production rule that is an alternation
      # of terminals and non-terminals
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_names [Array<Symbol>] the terms in the rule
      #@eskimobear.specification
      # Prop: The first set is the union of the first set of each
      #       term in the rule definition
      def make_alternation_rule(new_rule_name, rule_names)
        partial_status = include_rules?(rule_names) ? false : true
        first_set_alt = if partial_status
                          []
                        else
                          rule_names.map{|i| get_rule(i).first_set}.flatten.uniq
                        end
        inherited_partial_status = rule_names.any? do |i|
          include_rule?(i) ? get_rule(i).partial_status : true
        end
        partial_status = inherited_partial_status || partial_status
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        first_set_alt,
                        partial_status,
                        ebnf_alt(rule_names))
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
      #@eskimobear.specification
      # Prop: The first set is the union of the first set of the single
      #       term in the rule definition and the special terminal
      #       'nullable'
      def make_repetition_rule(new_rule_name, rule_name)
        partial_status = if include_rule?(rule_name)
                        get_rule(rule_name).partial_status
                      else
                        true
                         end
        ebnf = ebnf_rep(rule_name)
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        first_set_rep(ebnf, partial_status),
                        partial_status,
                        ebnf)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_rep(rule_name)
        EBNF::RepetitionRule.new(rule_to_term(rule_name)) 
      end

      def first_set_rep(ebnf, partial_status)
        if partial_status
          [:nullable]
        else
          Array.new(get_rule(ebnf.term.rule_name).first_set).push(:nullable)
        end
      end

      #Create a non-terminal production rule of either a non-terminal
      #  or terminal
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_name [Array<Symbol>] the single term in the rule 
      #@eskimobear.specification
      # Prop: The first set is the union of first set of the single
      #       term in the rule definition and the special terminal
      #       'nullable'
      def make_option_rule(new_rule_name, rule_name)
        partial_status = if include_rule?(rule_name)
                           get_rule(rule_name).partial_status
                         else
                           true
                         end
        ebnf = ebnf_opt(rule_name)
        rule = Rule.new(new_rule_name,
                        /undefined/,
                        first_set_opt(ebnf, partial_status),
                        partial_status,
                        ebnf)
        if partial_status
          self.push rule
        else
          self.push rule.compute_start_rxp(self)
        end
      end

      def ebnf_opt(rule_name)
        EBNF::OptionRule.new(rule_to_term(rule_name))
      end

      def first_set_opt(ebnf, partial_status)
        first_set_rep(ebnf, partial_status)
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
        apply_first_set(rules)
        lang = result_lang.new *rules
        if top_rule_name.nil?
          lang
        else
          lang.make_top_rule(top_rule_name)
        end
      end

      def apply_first_set(rules)
        rules.each do |i|
          if i.partial_status
            compute_first_set(rules, i.name)
            i.partial_status = false
          end
        end
        rules
      end

      #Compute the first_set of rules with partial status
      #@param rules [Eson::Language::RuleSeq::Rules] An array of rules
      #@param rule_name [Symbol] name of rule with partil status
      def compute_first_set(rules, rule_name)
        rule = rules.get_rule(rule_name)
        set = if rule.alternation_rule?
                rule.term_names.each_with_object([]) do |i, a|
                  first_set = rules.get_rule(i).first_set
                  a.concat(first_set)
                end
              else
                rules.get_rule(rule.term_names.first).first_set
              end
        rule.first_set.concat set
      end
            
      protected
      
      def self.all_rules?(seq)
        seq.all? {|i| i.class == Rule }
      end
    end
  end
end
