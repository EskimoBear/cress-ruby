module Eson

  module Language
    
    extend self

    RuleSeqItemError = Class.new(StandardError)

    ITEM_ERROR_MESSAGE = "One or more of the sequence elements are not of the type Eson::Language::Rule"

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
    #      : :nullable is a boolean, true when the non-terminal is
    #         nullable
    NonTerminal = Struct.new(:rule_name, :control, :nullable)

    #EBNF production rule representation
    #@eskimobear.specification
    # Prop : Rule has a :name, :sequence and
    #        regex patterns for legal tokens that can start or 
    #        follow the rule.
    #      : :sequence is the EBNF control for concatenation. It is
    #        an array and concatenaton is implicit in the ordering of 
    #        When Rule represents a non-terminal it is an array of
    #        NonTerminals and Terminals. When Rule represents a
    #        terminal it is the empty array. 
    Rule = Struct.new(:name, :sequence, :start_rxp, :follow_rxp,) do

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

      def regex_match?(regex, string)
        #does not catch zero or more matches that return "", the empty string
        (string =~ apply_at_start(regex)).nil? ? false : true
      end      

      def terminal?
        self.sequence.empty?
      end
        
      def nonterminal?
        !terminal?
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

    class RuleSeq < Array

      def self.new(obj)
        array = super
        unless self.all_rules?(array)
          raise RuleSeqItemError, ITEM_ERROR_MESSAGE
        end
        array
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

      def make_concatenation_rxp(rule_names)
        if include_rules?(rule_names)
          rxp_strings = get_rxp_sources(rule_names)
          combination = rxp_strings.reduce("") do |memo, i|
            memo.concat(i)
          end
          apply_at_start(combination)
        else
          nil
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

      def get_rxp_sources(rule_array)
        rule_array.map do |i|
          self.find{|j| j.name == i}.start_rxp.source
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

      def build_language(lang_name)
        result_lang = Struct.new lang_name, *names do
          include LanguageOperations
        end
        result_lang.new *self
      end
            
      protected
      
      def self.all_rules?(sequence)
        sequence.all? {|i| i.class == Eson::Language::Rule }
      end
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
    # let := "let";
    # ref := "ref";
    # doc := "doc";
    # unknown_special_form := {JSON_char};
    # proc_prefix := "&";
    # colon := ":";
    # program_start := "{";
    # program_end := "}";
    # key_word := {JSON_char}; (*all characters excluding proc_prefix*)
    def e0
      rules = [variable_prefix_rule,
               word_rule,
               whitespace_rule,
               other_chars_rule,
               true_rule,
               false_rule,
               number_rule,
               array_start_rule,
               array_end_rule,
               comma_rule,
               let_rule,
               ref_rule,
               doc_rule,
               unknown_special_form_rule,
               proc_prefix_rule,
               colon_rule,
               program_start_rule,
               program_end_rule,
               key_word_rule]
      Eson::Language::RuleSeq.new(rules).build_language("E0")
    end

    def rule_names(rule_seq)
      rule_seq.each_with_object([]) do |i, a|
        a.push(i.name)
      end
    end
    
    # variable_prefix := "$";
    def variable_prefix_rule
      Rule.new(:variable_prefix,
               [],
               variable_prefix_rxp)
    end

    def variable_prefix_rxp
      /\$/
    end
    
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    def word_rule
      Rule.new(:word,
               [],
               word_rxp)
    end

    def word_rxp
      /[a-zA-Z\-_.\d]+/
    end
      
    # whitespace := {" "};
    def whitespace_rule
      Rule.new(:whitespace,
               [],
               whitespace_rxp)
    end

    def whitespace_rxp
      /[ ]+/
    end

    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    def other_chars_rule
      Rule.new(:other_chars,
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
      Rule.new(:true,
               [],
               true_rxp)
    end
    
    def true_rxp
      /true/
    end
    
    # false := "false";
    def false_rule
      Rule.new(:false,
               [],
               false_rxp)
    end
    
    def false_rxp
      /false/
    end

    # number := JSON_number;
    def number_rule
      Rule.new(:number,
               [],
               number_rxp)
    end

    def number_rxp
      /\d+/
    end

    # array_start := "[";
    def array_start_rule
      Rule.new(:array_start,
               [],
               array_start_rxp)
    end

    def array_start_rxp
      /\[/
    end
    
    # array_end := "]";
    def array_end_rule
      Rule.new(:array_end,
               [],
               array_end_rxp)
    end

    def array_end_rxp
      /\]/
    end
    
    # comma := ",";
    def comma_rule
      Rule.new(:comma,
               [],
               comma_rxp)
    end

    def comma_rxp
      /\,/
    end

    # let := "let";
    def let_rule
      Rule.new(:let,
               [],
               let_rxp)
    end

    def let_rxp
      /let\z/
    end
    
    # ref := "ref";
    def ref_rule
      Rule.new(:ref,
               [],
               ref_rxp)
    end

    def ref_rxp
      /ref\z/
    end
    
    # doc := "doc";
    def doc_rule
      Rule.new(:doc,
               [],
               doc_rxp)
    end

    def doc_rxp
      /doc\z/
    end

    # unknown_special_form := {JSON_char};
    def unknown_special_form_rule
      Rule.new(:unknown_special_form,
               [],
               all_chars_rxp)
    end

    def all_chars_rxp
      /.+/
    end
    
    # proc_prefix := "&";
    def proc_prefix_rule
      Rule.new(:proc_prefix,
               [],
               proc_prefix_rxp)
    end

    def proc_prefix_rxp
      /&/
    end
    
    # colon := ":";
    def colon_rule
      Rule.new(:colon,
               [],
               colon_rxp)
    end

    def colon_rxp
      /:/
    end
    
    # program_start := "{";
    def program_start_rule
      Rule.new(:program_start,
               [],
               program_start_rxp)
    end

    def program_start_rxp
      /\{/
    end
    
    # program_end := "}";
    def program_end_rule
      Rule.new(:program_end,
               [],
               program_end_rxp)
    end

    def program_end_rxp
      /\}/
    end
    
    # key_word := {JSON_char}; (*all characters excluding proc_prefix*)
    def key_word_rule
      Rule.new(:key_word,
               [],
               all_chars_rxp)
    end

    #@return e1 the second language of the compiler
    #@eskimobear.specification
    #  Prop : E1 is a struct of eson production rules of
    #         E0 with 'unknown_special_form' removed  
    def e1
      e0.rule_seq.remove_rules([:unknown_special_form]).build_language("E1")
    end

    #@return e2 the third language of the compiler
    #@eskimobear.specification
    #  Prop : E2 is a struct of eson production rules of
    #         E1 with 'variable_prefix' and 'word' combined
    #         into 'variable_identifier'
    def e2
      e1.rule_seq.combine_rules([:variable_prefix, :word], :variable_identifier)
        .remove_rules([:variable_prefix])
        .build_language("E2")
    end

    module LanguageOperations

      def rule_seq
        Eson::Language::RuleSeq.new self.values
      end

      def to_s
        "#{self.class} has rules: ".concat(self.members.join(", "))
      end
      
      def rule_names(rule_seq)
        rule_seq.each_with_object([]) do |i, a|
          a.push(i.name)
        end
      end
            
      def get_top_rule
        self.members.last
      end

      def make_alternation(rule_array)
        if valid_rules?(rule_array)
          rxp_strings = get_rxp_sources(rule_array)
          initial = rxp_strings.first
          rest = rxp_strings.drop(1)
          combination = rest.reduce(initial) do |memo, i|
            memo.concat("|").concat(i)
          end
          apply_at_start(combination)
        else
          nil #TODO throw an exception or catch TypeError exception higher up
        end
      end

      def valid_rules?(rule_array)
        rule_array.all?{ |i| valid_rule? i }
      end

      def valid_rule?(rule_name) 
        if rule_name.is_a? String
          self.members.include? rule_name.intern
        elsif rule_name.is_a? Symbol
          self.members.include? rule_name
        else
          false
        end
      end

      def get_rxp_sources(rule_array)
        rule_array.map do |i|
          self.send(i).start_rxp.source
        end
      end
      
      def apply_at_start(rxp_string)
        /\A(#{rxp_string})/
      end

      #Automatically generate the start_regex for a rule
      #@return [Regexp] the regexp that matches valid start strings
      #                 for this rule
      #@eskimobear.specification
      #inspect self.sequence
      #substitute all NonTerminals with their Terminals
      #construct regex by applying :control to Terminal :regexp
      #
      #when :sequence has all Terminals and all nil :control
      #  :start_regex -> :sequence.first.regex
      #
      #when :sequence has all Terminals and all :choice
      #  :start_regex -> :sequence.each.regex.source |
      def get_start_regex
      end
    end

    alias_method :tokenizer_lang, :e0
    alias_method :verified_special_forms_lang , :e1
  end
end
