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

    module EBNF

      Terminal = Struct.new(:rule_name)
      NonTerminal = Struct.new(:rule_name)
            
      ConcatenationRule = Struct.new(:term_list)
      AlternationRule = Struct.new(:term_set)
      RepetitionRule = Struct.new(:term)
      OptionRule = Struct.new(:term)
      
    end

    class RuleSeq < Array

      ItemError = Class.new(StandardError)
      ConversionError = Class.new(StandardError)

      #EBNF terminal representation
      #@eskimobear.specification
      # Prop : Terminals have a :rule_name and :control.
      #      : :rule_name is the Rule.name of the matching production
      #        rule for a terminal.
      #      : :control is the set of EBNF controls applied to a
      #          Terminal or NonTerminal consisting of :choice,
      #          :option and/or :repetition.
      Terminal = Struct.new(:rule_name, :control)

      #EBNF non-terminal representation
      #@eskimobear.specification
      # Prop : NonTerminals have a :rule_name and :control
      #      : :rule_name is the Rule.name of the matching production
      #        rule for a non-terminal.
      #      : :control is the set of EBNF controls applied to a
      #          Terminal or NonTerminal. Consisting of :choice,
      #          :option and/or :repetition.
      NonTerminal = Struct.new(:rule_name, :control)
      
      #EBNF production rule representation for terminals and non-terminals
      class Rule

        include EBNF

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
        #   from an undefined term
        #@param nullable [Boolean] false for terminals and initially, true when
        #  rule is repetition or option.
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

        def nullable?
          if option_rule? || repetition_rule?
            true
          else
            false
          end
        end

        def term_names
          if terminal?
            nil
          elsif alternation_rule?
            ebnf.term_set.map{|i| i.rule_name}
          elsif concatenation_rule?
            ebnf.term_list.map{|i| i.rule_name}
          elsif repetition_rule? || option_rule?
            [ebnf.term.rule_name]
          end
        end
        
        #TODO switch to ebnf
        #FIXME this no longer works as terminals which have been
        #converted from nonterminals have a nil start_rxp
        def to_s       
          "#{name} := #{ebnf_to_s};"
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
          ebnf.instance_of? EBNF::AlternationRule
        end

        def concatenation_rule?
          ebnf.instance_of? EBNF::ConcatenationRule
        end

        def repetition_rule?
          ebnf.instance_of? EBNF::RepetitionRule
        end

        def option_rule?
          ebnf.instance_of? EBNF::OptionRule
        end

        def join_rule_names(terms, infix="")
          initial = terms.first.rule_name.to_s
          rest = terms.drop(1)
          rest.each_with_object(initial){|i, memo| memo.concat(infix).concat(i.rule_name.to_s)}
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

        def terminal?
          self.ebnf.nil?
        end
        
        def nonterminal?
          !terminal?
        end

        def apply_at_start(regex)
          /\A#{regex.source}/
        end

        #Compute the start rxp of non terminal rule
        #@param rules [Eson::Language::RuleSeq]
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
            if rules.get_rule(i).rxp.nil?
              pp rules.get_rule(i).name
              pp rules.get_rule(i).terminal?
              pp rules.get_rule(i).rxp
            end
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

      def combine_rules(rule_names, new_rule_name)
        if include_rules?(rule_names)
          self.push(Rule.new(new_rule_name, make_concatenation_rxp(rule_names)))
        else
          nil
        end
      end

      def convert_to_terminal(rule_name)
        if partial_rule?(rule_name)
          raise ConversionError, conversion_error_message(rule_name)
        elsif !include_rule?(rule_name)
          raise ItemError, missing_item_error_message(rule_name)
        end
        self.map! do |rule|
          new_rule = if rule_name == rule.name
                       if partial_rule?(rule.name)
                         Rule.new_terminal_rule(rule.name, /undefined/).compute_start_rxp(self)
                       else
                         Rule.new_terminal_rule(rule.name, rule.rxp)
                       end
                     else
                       rule
                     end
          new_rule
        end
      end

      def conversion_error_message(rule_name)
        "The Rule #{rule_name} has partial status and thus has an undefined regular expression. This Rule cannot be converted to a terminal Rule."
      end
        
      def partial_rule?(rule_name)
        self.get_rule(rule_name).partial_status
      end
        
      def make_terminal_rule(new_rule_name, rxp)
        self.push(Rule.new_terminal_rule(new_rule_name, rxp))
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

      #Create a non-terminal production rule with repetition
      #  controls
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

      #Create a non-terminal production rule with option
      #  controls
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

    # null := "nil";
    def null_rule
      RuleSeq::Rule.new_terminal_rule(:null, null_rxp)
    end

    def null_rxp
      /null/
    end
    
    # variable_prefix := "$";
    def variable_prefix_rule
      RuleSeq::Rule.new_terminal_rule(:variable_prefix, variable_prefix_rxp)
    end

    def variable_prefix_rxp
      /\$/
    end
    
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    def word_rule
      RuleSeq::Rule.new_terminal_rule(:word, word_rxp)
    end

    def word_rxp
      /[a-zA-Z\-_.\d]+/
    end
      
    # whitespace := {" "};
    def whitespace_rule
      RuleSeq::Rule.new_terminal_rule(:whitespace, whitespace_rxp)
    end

    def whitespace_rxp
      /[ ]+/
    end

    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    def other_chars_rule
      RuleSeq::Rule.new_terminal_rule(:other_chars, other_chars_rxp)
    end
    
    def other_chars_rxp
      word = word_rxp.source
      variable_prefix = variable_prefix_rxp.source
      whitespace = whitespace_rxp.source
      /[^#{word}#{variable_prefix}#{whitespace}]+/
    end

    # true := "true";
    def true_rule
      RuleSeq::Rule.new_terminal_rule(:true, true_rxp)
    end
    
    def true_rxp
      /true/
    end
    
    # false := "false";
    def false_rule
      RuleSeq::Rule.new_terminal_rule(:false, false_rxp)
    end
    
    def false_rxp
      /false/
    end

    # number := JSON_number;
    def number_rule
      RuleSeq::Rule.new_terminal_rule(:number, number_rxp)
    end

    def number_rxp
      /\d+/
    end

    # array_start := "[";
    def array_start_rule
      RuleSeq::Rule.new_terminal_rule(:array_start, array_start_rxp)
    end

    def array_start_rxp
      /\[/
    end
    
    # array_end := "]";
    def array_end_rule
      RuleSeq::Rule.new_terminal_rule(:array_end, array_end_rxp)
    end

    def array_end_rxp
      /\]/
    end
    
    # comma := ",";
    def comma_rule
      RuleSeq::Rule.new_terminal_rule(:comma, comma_rxp)
    end

    def comma_rxp
      /\,/
    end

    # end_of_line := ",";
    def end_of_line_rule
      RuleSeq::Rule.new_terminal_rule(:end_of_line, comma_rxp)
    end
    
    # let := "let";
    def let_rule
      RuleSeq::Rule.new_terminal_rule(:let, let_rxp)
    end

    def let_rxp
      /let\z/
    end
    
    # ref := "ref";
    def ref_rule
      RuleSeq::Rule.new_terminal_rule(:ref, ref_rxp)
    end

    def ref_rxp
      /ref\z/
    end
    
    # doc := "doc";
    def doc_rule
      RuleSeq::Rule.new_terminal_rule(:doc, doc_rxp)
    end

    def doc_rxp
      /doc\z/
    end

    # unknown_special_form := {JSON_char};
    def unknown_special_form_rule
      RuleSeq::Rule.new_terminal_rule(:unknown_special_form, all_chars_rxp)
    end

    def all_chars_rxp
      /.+/
    end
    
    # proc_prefix := "&";
    def proc_prefix_rule
      RuleSeq::Rule.new_terminal_rule(:proc_prefix, proc_prefix_rxp)
    end

    def proc_prefix_rxp
      /&/
    end
    
    # colon := ":";
    def colon_rule
      RuleSeq::Rule.new_terminal_rule(:colon, colon_rxp)
    end

    def colon_rxp
      /:/
    end
    
    # program_start := "{";
    def program_start_rule
      RuleSeq::Rule.new_terminal_rule(:program_start, program_start_rxp)
    end

    def program_start_rxp
      /\{/
    end
    
    # program_end := "}";
    def program_end_rule
      RuleSeq::Rule.new_terminal_rule(:program_end, program_end_rxp)
    end

    def program_end_rxp
      /\}/
    end
    
    # key_string := {JSON_char}; (*all characters excluding proc_prefix*)
    def key_string_rule
      RuleSeq::Rule.new_terminal_rule(:key_string, all_chars_rxp)
    end

    #eson formal language with tokens only
    #@return [E0] the initial compiler language used by Tokenizer
    #@eskimobear.specification
    # Prop : E0 is a struct of eson production rules for the language 
    #
    # The following EBNF rules describe the eson grammar, E0:
    # variable_prefix := "$";
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    # whitespace := {" "};
    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    # true := "true";
    # false := "false";
    # number := JSON_number;
    # null := "null";
    # array_start := "[";
    # array_end := "]";
    # comma := ",";
    # end_of_line := ",";
    # let := "let";
    # ref := "ref";
    # doc := "doc";
    # unknown_special_form := {JSON_char};
    # proc_prefix := "&";
    # colon := ":";
    # program_start := "{";
    # program_end := "}";
    # key_string := {JSON_char}; (*all characters excluding proc_prefix*)
    # special_form := let | ref | doc;
    # word_form := whitespace | variable_prefix | word | other_chars;
    # variable_identifier := variable_prefix, word;
    def e0
      rules = [variable_prefix_rule,
               word_rule,
               whitespace_rule,
               other_chars_rule,
               true_rule,
               false_rule,
               null_rule,
               number_rule,
               array_start_rule,
               array_end_rule,
               comma_rule,
               end_of_line_rule,
               let_rule,
               ref_rule,
               doc_rule,
               unknown_special_form_rule,
               proc_prefix_rule,
               colon_rule,
               program_start_rule,
               program_end_rule,
               key_string_rule]
      Eson::Language::RuleSeq.new(rules)
        .make_alternation_rule(:special_form, [:let, :ref, :doc])
        .make_alternation_rule(:word_form, [:whitespace, :variable_prefix, :word, :other_chars])
        .make_concatenation_rule(:variable_identifier, [:variable_prefix, :word])
        .make_concatenation_rule(:proc_identifier, [:proc_prefix, :special_form])
        .build_language("E0")
    end

    #@return e1 the second language of the compiler
    #@eskimobear.specification
    #  Prop : E1 is a struct of eson production rules of
    #         E0 with 'unknown_special_form' removed  
    def e1
      e0.rule_seq
        .remove_rules([:unknown_special_form])
        .build_language("E1")
    end

    #@return e2 the third language of the compiler
    #@eskimobear.specification
    #  Prop : E2 is a struct of eson production rules
    #         of E1 with 'variable_identifier' and 'proc identifier'
    #         converted to terminals.
    def e2
      e1.rule_seq
        .convert_to_terminal(:variable_identifier)
        .convert_to_terminal(:proc_identifier)
        .make_alternation_rule(:key, [:proc_identifier, :key_string])
        .remove_rules([:let, :ref, :doc, :proc_prefix, :special_form])
        .build_language("E2")
    end

    #@return e3 the fourth language of the compiler
    #@eskimobear.specification
    #  Prop : E3 is a struct of eson production rules of E2 with
    #         'word_form' tokenized and
    #         'whitespace', 'variable_prefix', 'word' and 
    #         'other_chars' removed.    
    def e3
      e2.rule_seq.convert_to_terminal(:word_form)
        .remove_rules([:other_chars, :variable_prefix, :word, :whitespace])
        .build_language("E3")
    end

    #@return e4 the fifth language of the compiler
    #@eskimobear.specification
    # Prop : E4 is a struct of eson production rules of E3 with
    #        'sub_string' production rule added.
    def e4
      e3.rule_seq.make_alternation_rule(:sub_string, [:word_form, :variable_identifier])
        .make_terminal_rule(:string_delimiter, /"/)
        .make_repetition_rule(:sub_string_list, :sub_string)
        .make_concatenation_rule(:string, [:string_delimiter, :sub_string_list, :string_delimiter])
        .build_language("E4")
    end

    #@return e5 the sixth language of the compiler
    #@eskimobear.specification
    # Prop : E5 is a struct of eson production rules of E4 with
    #        recursive production rules such as 'value', 'array',
    #        and 'program' added.
    def e5
      e4.rule_seq
        .make_alternation_rule(:value, [:variable_identifier, :true, :false,
                                        :null, :string, :number, :array, :program])
        .make_concatenation_rule(:element_more_once, [:comma, :value])
        .make_repetition_rule(:element_more, :element_more_once)
        .make_concatenation_rule(:element_list, [:value, :element_more])
        .make_option_rule(:element_set, :element_list)
        .make_concatenation_rule(:array, [:array_start, :element_set, :array_end])
        .make_concatenation_rule(:declaration, [:key, :colon, :value])
        .make_concatenation_rule(:declaration_more_once, [:comma, :declaration])
        .make_repetition_rule(:declaration_more, :declaration_more_once)
        .make_concatenation_rule(:declaration_list, [:declaration, :declaration_more])
        .make_option_rule(:declaration_set, :declaration_list)
        .make_concatenation_rule(:program, [:program_start, :declaration_set, :program_end])
        .build_language("E5", :program)
    end

    alias_method :tokenizer_lang, :e0
    alias_method :verified_special_forms_lang, :e1
    alias_method :tokenize_variable_identifier_lang, :e2
    alias_method :tokenize_word_form_lang, :e3
    alias_method :label_sub_string_lang, :e4
    alias_method :insert_string_delimiter_lang, :e4
  end
end
