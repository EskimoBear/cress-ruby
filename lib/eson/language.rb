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

    class RuleSeq < Array

      ItemError = Class.new(StandardError)

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

        attr_accessor :name, :sequence, :start_rxp, :first_set, :nullable, :partial_status

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
        #@param partial_first [Boolean] false if first_set is incomplete, this occurs
        #   when sequence contains recursive terms either directly or indirectly.
        #@param nullable [Boolean] false for terminals and initially, true when
        #  rule is repetition or option.
        def initialize(name, sequence, start_rxp=nil, first_set=nil, nullable=nil, partial_status=nil)
          @name = name
          @sequence = sequence
          @start_rxp = start_rxp
          @first_set = terminal? ? [name] : first_set
          @nullable = terminal? ? false : nullable
          @partial_status = terminal? ? false : partial_status
        end
        
        ControlError = Class.new(StandardError)

        def get_rule(rule_name)
          Language.send(pedigree).send(rule_name)
        end

        #FIXME this no longer works as terminals which have been
        #converted from nonterminals have a nil start_rxp
        def to_s       
          "#{name} := #{sequence_to_s};"
        end

        def sequence_to_s
          if terminal?
            "\"#{start_rxp.source.gsub(/\\/, "")}\""
          elsif alternation?
            join_rule_name(" | ")
          elsif concatenation?
            join_rule_name(", ")
          elsif repetition?
            "{#{join_rule_name}}"
          elsif option?
            "[#{join_rule_name}]"
          end
        end
        
        def concatenation?
          sequence.all?{|i| i.control == :none}
        end

        def alternation?
          self.sequence.all?{|i| i.control == :choice}
        end
        
        def repetition?
          sequence.length.eql?(1) && sequence.first.control == :repetition
        end

        def option?
          sequence.length.eql?(1) && sequence.first.control == :option
        end
      
        def join_rule_name(infix="")
          initial = sequence.first.rule_name.to_s
          rest = sequence.drop(1)
          rest.each_with_object(initial){|i, memo| memo.concat(infix).concat(i.rule_name.to_s)}
        end
        
        def match(string)
          string.match(self.rxp)
        end

        def rxp
          if self.terminal?
            apply_at_start(self.start_rxp)
          else
            nil
          end
        end
        
        def match_rxp?(string)
          regex_match?(self.rxp, string)
        end

        def match_start(string)
          if self.nonterminal?
            string.match(self.start_rxp)
          else
            nil
          end
        end

        def regex_match?(regex, string)
          #does not catch zero or more matches that return "", the empty string
          (string =~ apply_at_start(regex)).nil? ? false : true
        end      

        def terminal?
          self.sequence.nil? || self.sequence.empty?
        end
        
        def nonterminal?
          !terminal?
        end

        def rule_symbol(control=:none)
          unless valid_control?(control)
            raise ControlError, wrong_control_option_error_message(control)
          end
          if terminal?
            Terminal[self.name, control]
          else
            NonTerminal[self.name, control]
          end
        end

        def valid_control?(control)
          control_options.include? control
        end

        def control_options
          [:choice, :repetition, :option, :none]
        end

        def wrong_control_option_error_message(control)
          "#{control} is not a valid control option. Try one of the following #{control_options.join(", ")}"
        end

        def valid_start?(string)
          regex_match?(self.start_regex, string)
        end
        
        def valid_follow?(string)
          regex_match?(self.follow_regex, string)
        end

        def apply_at_start(regex)
          /\A#{regex.source}/
        end
      end    
      
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
          self.push(Rule.new(new_rule_name,
                             [],
                             make_concatenation_rxp(rule_names)))
        else
          nil
        end
      end

      def convert_to_terminal(rule_name)
        unless include_rule?(rule_name)
          raise ItemError, missing_item_error_message(rule_name)
        end
        self.map! do |rule|
          if rule_name == rule.name
            Rule.new(rule.name,
                     [],
                     rule.start_rxp)
          else
            rule
          end
        end
      end

      def make_terminal_rule(new_rule_name, rxp)
        self.push(Rule.new(new_rule_name,
                           [],
                           rxp))
      end

      #Create a non-terminal production rule with concatenation
      #  controls
      #@param new_rule_name [Symbol] name of the production rule
      #@param rule_names [Array<Symbol>] sequence of the terms in
      #  the rule given in order
      #@eskimobear.specification
      # Prop: The first set of is the first set of the first term
      #       of the rule definition
      def make_concatenation_rule(new_rule_name, rule_names)
        partial_status = include_rules?(rule_names) ? false : true
        first_rule_name = rule_names.first
        term_seq = rule_term_concatenation(rule_names)
        inherited_partial_status = if include_rule?(first_rule_name)
                                     get_rule(first_rule_name).partial_status
                                   else
                                     true
                                   end
        partial_status = inherited_partial_status || partial_status
        self.push(Rule.new(new_rule_name,
                           term_seq,
                           self.make_concatenation_rxp(rule_names),
                           first_set_concat(term_seq, partial_status),
                           false,
                           partial_status))
      end

      def first_set_concat(term_seq, partial_status)
        first = term_seq.first
        if partial_status
          []
        else
          get_rule(first.rule_name).first_set
        end
      end

      def rule_term_concatenation(rule_names)
        rule_names.map do |i|
          if self.include? i
            get_rule(i).rule_symbol
          else
            NonTerminal[i, :none]
          end
        end
      end

      #Create a non-terminal production rule with alternation
      #  controls
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
        term_seq = rule_term_alternation(rule_names)
        inherited_partial_status = rule_names.any? do |i|
          include_rule?(i) ? get_rule(i).partial_status : true
        end
        partial_status = inherited_partial_status || partial_status
        self.push(Rule.new(new_rule_name,
                           term_seq,
                           make_alternation_rxp(rule_names),
                           first_set_alt,
                           false,
                           partial_status))
      end

      def rule_term_alternation(rule_names)
        terms = rule_names.map do |i|
          if include_rule?(i)
            get_rule(i).rule_symbol(:choice)
          else
            NonTerminal[i, :choice] #if the term has not been defined yet add it as a nonterminal
          end
        end
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
        term_seq = rule_term_repetition(rule_name)
        self.push(Rule.new(new_rule_name,
                           term_seq,
                           self.make_repetition_rxp(rule_name),
                           first_set_rep(term_seq, partial_status),
                           true,
                           partial_status))
      end

      def rule_term_repetition(rule_name)
        if include_rule?(rule_name)
          [get_rule(rule_name).rule_symbol(:repetition)]
        else
          [NonTerminal[rule_name, :repetition]]
        end
      end
      
      def first_set_rep(term_seq, partial_status)
        first = term_seq.first
        if partial_status
          [:nullable]
        else
          Array.new(get_rule(first.rule_name).first_set).push(:nullable)
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
        term_seq = rule_term_option(rule_name)
        self.push(Rule.new(new_rule_name,
                           term_seq,
                           self.make_option_rxp(rule_name),
                           first_set_opt(term_seq, partial_status),
                           true,
                           partial_status))
      end

      def rule_term_option(rule_name)
        if include_rule?(rule_name)
          [].push(get_rule(rule_name).rule_symbol(:option))
        else
          [NonTerminal[rule_name, :option]]
        end
      end

      def first_set_opt(term_seq, partial_status)
        first_set_rep(term_seq, partial_status)
      end
                  
      def missing_items_error_message(rule_names)
        names = rule_names.map{|i| ":".concat(i.to_s)}
        "One or more of the following Eson::Language::Rule.name's are not present in the sequence: #{names.join(", ")}."
      end

      def make_option_rxp(rule_name)
        make_repetition_rxp(rule_name)
      end

      def make_repetition_rxp(rule_name)
        if include_rule?(rule_name)
          get_rule(rule_name).start_rxp
        else
          /P/
        end
      end
      
      def make_concatenation_rxp(rule_names)
        if include_rules?(rule_names)
          rxp_strings = get_rxp_sources(rule_names)
          combination = rxp_strings.reduce("") do |memo, i|
            memo.concat(i)
          end
          apply_at_start(combination)
        else
          /P/
        end
      end

      def make_alternation_rxp(rule_names)
        if include_rules?(rule_names)
          rxp_strings = get_rxp_sources(rule_names)
          initial = rxp_strings.first
          rest = rxp_strings.drop(1)
          combination = rest.reduce(initial) do |memo, i|
            memo.concat("|").concat(i)
          end
          apply_at_start(combination)
        else
          /P/
        end
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

      def get_rxp_sources(rule_array)
        rule_array.map do |i|
          get_rule(i).start_rxp.source
        end
      end
      
      def apply_at_start(rxp_string)
        /\A(#{rxp_string})/
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
          end
        end
        rules
      end
              
      #Compute the first_set of rules with partial status
      #@param rules [Eson::Language::RuleSeq::Rules] An array of rules
      #@param rule_name [Symbol] name of rule with partial first_set
      def compute_first_set(rules, rule_name)
        rule = rules.get_rule(rule_name)
        terms = rule.sequence
        set = if rule.alternation?
                terms.each_with_object([]) do |i, a|
                  first_set = rules.get_rule(i.rule_name).first_set
                  a.concat(first_set)
                end
              else
                rules.get_rule(terms.first.rule_name).first_set
              end
        rule.first_set.concat set
        rule.partial_status = false
      end
            
      protected
      
      def self.all_rules?(sequence)
        sequence.all? {|i| i.class == Rule }
      end
    end

    # null := "nil";
    def null_rule
      RuleSeq::Rule.new(:null,
                        [],
                        null_rxp)
    end

    def null_rxp
      /null/
    end
    
    # variable_prefix := "$";
    def variable_prefix_rule
      RuleSeq::Rule.new(:variable_prefix,
               [],
               variable_prefix_rxp)
    end

    def variable_prefix_rxp
      /\$/
    end
    
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    def word_rule
      RuleSeq::Rule.new(:word,
               [],
               word_rxp)
    end

    def word_rxp
      /[a-zA-Z\-_.\d]+/
    end
      
    # whitespace := {" "};
    def whitespace_rule
      RuleSeq::Rule.new(:whitespace,
               [],
               whitespace_rxp)
    end

    def whitespace_rxp
      /[ ]+/
    end

    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    def other_chars_rule
      RuleSeq::Rule.new(:other_chars,
               [],
               other_chars_rxp)
    end
    
    def other_chars_rxp
      word = word_rxp.source
      variable_prefix = variable_prefix_rxp.source
      whitespace = whitespace_rxp.source
      /[^#{word}#{variable_prefix}#{whitespace}]+/
    end

    # true := "true";
    def true_rule
      RuleSeq::Rule.new(:true,
               [],
               true_rxp)
    end
    
    def true_rxp
      /true/
    end
    
    # false := "false";
    def false_rule
      RuleSeq::Rule.new(:false,
               [],
               false_rxp)
    end
    
    def false_rxp
      /false/
    end

    # number := JSON_number;
    def number_rule
      RuleSeq::Rule.new(:number,
               [],
               number_rxp)
    end

    def number_rxp
      /\d+/
    end

    # array_start := "[";
    def array_start_rule
      RuleSeq::Rule.new(:array_start,
               [],
               array_start_rxp)
    end

    def array_start_rxp
      /\[/
    end
    
    # array_end := "]";
    def array_end_rule
      RuleSeq::Rule.new(:array_end,
               [],
               array_end_rxp)
    end

    def array_end_rxp
      /\]/
    end
    
    # comma := ",";
    def comma_rule
      RuleSeq::Rule.new(:comma,
               [],
               comma_rxp)
    end

    def comma_rxp
      /\,/
    end

    # end_of_line := ",";
    def end_of_line_rule
      RuleSeq::Rule.new(:end_of_line,
                        [],
                        comma_rxp)
    end
    
    # let := "let";
    def let_rule
      RuleSeq::Rule.new(:let,
               [],
               let_rxp)
    end

    def let_rxp
      /let\z/
    end
    
    # ref := "ref";
    def ref_rule
      RuleSeq::Rule.new(:ref,
               [],
               ref_rxp)
    end

    def ref_rxp
      /ref\z/
    end
    
    # doc := "doc";
    def doc_rule
      RuleSeq::Rule.new(:doc,
               [],
               doc_rxp)
    end

    def doc_rxp
      /doc\z/
    end

    # unknown_special_form := {JSON_char};
    def unknown_special_form_rule
      RuleSeq::Rule.new(:unknown_special_form,
               [],
               all_chars_rxp)
    end

    def all_chars_rxp
      /.+/
    end
    
    # proc_prefix := "&";
    def proc_prefix_rule
      RuleSeq::Rule.new(:proc_prefix,
               [],
               proc_prefix_rxp)
    end

    def proc_prefix_rxp
      /&/
    end
    
    # colon := ":";
    def colon_rule
      RuleSeq::Rule.new(:colon,
               [],
               colon_rxp)
    end

    def colon_rxp
      /:/
    end
    
    # program_start := "{";
    def program_start_rule
      RuleSeq::Rule.new(:program_start,
               [],
               program_start_rxp)
    end

    def program_start_rxp
      /\{/
    end
    
    # program_end := "}";
    def program_end_rule
      RuleSeq::Rule.new(:program_end,
               [],
               program_end_rxp)
    end

    def program_end_rxp
      /\}/
    end
    
    # key_string := {JSON_char}; (*all characters excluding proc_prefix*)
    def key_string_rule
      RuleSeq::Rule.new(:key_string,
               [],
               all_chars_rxp)
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
