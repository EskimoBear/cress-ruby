require_relative 'rule_seq.rb'

module Eson
  module EsonGrammars

    extend self

    RuleSeq =  Eson::RuleSeq
    Rule = Eson::Rule

    # null := "nil";
    def null_rule
      Rule.new_terminal_rule(:null, null_rxp)
    end

    def null_rxp
      /null\z/
    end
    
    # variable_prefix := "$";
    def variable_prefix_rule
      Rule.new_terminal_rule(:variable_prefix, variable_prefix_rxp)
    end

    def variable_prefix_rxp
      /\$/
    end

    def variable_identifier_rxp
      variable_prefix = variable_prefix_rxp.source
      word = word_rxp.source
      /#{variable_prefix}#{word}/
    end
    
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    def word_rule
      Rule.new_terminal_rule(:word, word_rxp)
    end

    def word_rxp
      /[a-zA-Z\-_.\d]+/
    end
    
    # whitespace := {" "};
    def whitespace_rule
      Rule.new_terminal_rule(:whitespace, whitespace_rxp)
    end

    def whitespace_rxp
      /[ ]+/
    end

    # empty_word := "";
    def empty_word_rule
      Rule.new_terminal_rule(:empty_word, empty_word_rxp)
    end
    
    def empty_word_rxp
      /^$/
    end

    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    def other_chars_rule
      Rule.new_terminal_rule(:other_chars, other_chars_rxp)
    end
    
    def other_chars_rxp
      word = word_rxp.source
      variable_prefix = variable_prefix_rxp.source
      whitespace = whitespace_rxp.source
      /[^#{word}#{variable_prefix}#{whitespace}]+/
    end

    # true := "true";
    def true_rule
      Rule.new_terminal_rule(:true, true_rxp)
    end
    
    def true_rxp
      /true\z/
    end
    
    # false := "false";
    def false_rule
      Rule.new_terminal_rule(:false, false_rxp)
    end
    
    def false_rxp
      /false\z/
    end

    # number := JSON_number;
    def number_rule
      Rule.new_terminal_rule(:number, number_rxp)
    end

    def number_rxp
      /\d+/
    end

    # array_start := "[";
    def array_start_rule
      Rule.new_terminal_rule(:array_start, array_start_rxp)
    end

    def array_start_rxp
      /\[/
    end
    
    # array_end := "]";
    def array_end_rule
      Rule.new_terminal_rule(:array_end, array_end_rxp)
    end

    def array_end_rxp
      /\]/
    end
    
    # comma := ",";
    def comma_rule
      Rule.new_terminal_rule(:comma, comma_rxp)
    end

    def comma_rxp
      /\,/
    end

    # end_of_line := ",";
    def end_of_line_rule
      Rule.new_terminal_rule(:end_of_line, comma_rxp)
    end
    
    # colon := ":";
    def colon_rule
      Rule.new_terminal_rule(:colon, colon_rxp)
    end

    def colon_rxp
      /:/
    end
    
    # program_start := "{";
    def program_start_rule
      Rule.new_terminal_rule(:program_start, program_start_rxp)
    end

    def program_start_rxp
      /\{/
    end
    
    # program_end := "}";
    def program_end_rule
      Rule.new_terminal_rule(:program_end, program_end_rxp)
    end

    def program_end_rxp
      /\}/
    end
    
    # key_string := {JSON_char}; (*all characters excluding proc_prefix*)
    def key_string_rule
      Rule.new_terminal_rule(:key_string, key_string_rxp)
    end

    def key_string_rxp
      proc_prefix = proc_prefix_rxp.source
      /\A[^#{proc_prefix}]+/
    end

    def proc_prefix_rxp
      /&/
    end

    def unreserved_procedure_identifier_rxp
      proc_prefix = proc_prefix_rxp.source
      /#{proc_prefix}(.+)/
    end

    #@return [R0] eson grammar for lexing keys
    def reserved_keys
      reserved = [:let, :ref, :doc]
      RuleSeq.new(make_reserved_keys_rules(reserved))
        .make_terminal_rule(:proc_prefix,
                            proc_prefix_rxp)
        .make_alternation_rule(:special_form_identifier, reserved)
        .convert_to_terminal(:special_form_identifier)
        .make_terminal_rule(
          :unreserved_procedure_identifier,
          unreserved_procedure_identifier_rxp)
        .make_terminal_rule(
          :key_string,
          key_string_rxp)
        .build_cfg("R0")
    end

    def make_reserved_keys_rules(keywords)
      keywords.map do |k|
        if k.is_a?(String) || k.is_a?(Symbol)
          k_name = k.is_a?(Symbol) ? k : k.intern
          k_string = k.is_a?(String) ? k : k.to_s
          Rule.new_terminal_rule(
            k_name,
            Regexp.new(
              proc_prefix_rxp.source
              .concat(k_string)
              .concat("\\z")))
        end
      end
    end

    #
    #@return [E0] the initial eson grammar used for tokenization
    def e0
      rules = [word_rule,
               whitespace_rule,
               empty_word_rule,
               other_chars_rule,
               true_rule,
               false_rule,
               null_rule,
               number_rule,
               array_start_rule,
               array_end_rule,
               comma_rule,
               end_of_line_rule,
               colon_rule,
               program_start_rule,
               program_end_rule,
               key_string_rule]
      RuleSeq.new(reserved_keys
                   .copy_rules
                   .concat(rules))
        .make_terminal_rule(:variable_identifier,
                           variable_identifier_rxp)
        .make_alternation_rule(:word_form,
                               [:whitespace,
                                :word,
                                :empty_word,
                                :other_chars])
        .convert_to_terminal(:word_form)
        .make_alternation_rule(:proc_identifier,
                                 [:unreserved_procedure_identifier,
                                  :special_form_identifier])
        .build_cfg("E0")
    end

    #@return e4 the fifth language of the compiler
    #@eskimobear.specification
    # Prop : E4 is a struct of eson production rules of E3 with
    #        'sub_string' production rule added.
    def e4
      e0.copy_rules
        .make_alternation_rule(:sub_string, [:word_form, :variable_identifier])
        .make_terminal_rule(:string_delimiter, /"/)
        .make_repetition_rule(:sub_string_list, :sub_string)
        .make_concatenation_rule(:string, [:string_delimiter, :sub_string_list, :string_delimiter])
        .build_cfg("E4")
    end

    #@return e5 the sixth language of the compiler
    #@eskimobear.specification
    # Prop : E5 is a struct of eson production rules of E4 with
    #        recursive production rules such as 'value', 'array',
    #        and 'program' added.
    def e5
      e4.copy_rules
        .make_alternation_rule(:value, [:variable_identifier, :true, :false,
                                        :null, :string, :number, :array, :program])
        .make_concatenation_rule(:element_more_once, [:comma, :value])
        .make_repetition_rule(:element_more, :element_more_once)
        .make_concatenation_rule(:element_list, [:value, :element_more])
        .make_option_rule(:element_set, :element_list)
        .make_concatenation_rule(:array, [:array_start, :element_set, :array_end])
        .make_concatenation_rule(:attribute, [:key_string, :colon, :value])
        .make_concatenation_rule(:call, [:proc_identifier, :colon, :value])
        .make_alternation_rule(:declaration, [:call, :attribute])
        .make_concatenation_rule(:declaration_more_once, [:end_of_line, :declaration])
        .make_repetition_rule(:declaration_more, :declaration_more_once)
        .make_concatenation_rule(:declaration_list, [:declaration, :declaration_more])
        .make_option_rule(:declaration_set, :declaration_list)
        .make_concatenation_rule(:program, [:program_start, :declaration_set, :program_end])
        .build_cfg("E5", :program)
    end

    alias_method :tokenizer_lang, :e0
    alias_method :syntax_pass_lang, :e5
    alias_method :label_sub_string_lang, :e4
    alias_method :insert_string_delimiter_lang, :e4
  end
end
