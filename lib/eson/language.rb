module Eson

  module Language
    extend self

    Terminal = Struct.new(:name, :controls)
    Rule = Struct.new(:name, :sequence)
    NonTerminal = Struct.new(:name, :rule, :controls)
    #Return the initial formal language of the compiler
    #@return L0 the initial eson language
    #@eson.specification
    # Prop : L0 is a struct of eson production rules
    #      : production rule, a Rule struct of name and sequence
    #      : name, symbol of Rule, Terminal or NonTerminal
    #      : sequence, the EBNF control for concatenation
    #          it is an array of NonTerminals and Terminals
    #      : Terminals are structs with type and operation
    #      : NonTerminals are structs with type, rule and operation
    #      : controls is the set of EBNF controls applied to a
    #          Terminal or NonTerminal. Consisting of :choice,
    #          :option and/or :repetition. The sequence control is
    #          implicit in the ordering of Rule's sequence member.
    #
    #The following EBNF rules describe the eson grammar, L0:
    # variable_prefix := "$";
    # word := {JSON_char}; (*letters, numbers, '-', '_', '.'*)
    # variable_identifier := variable_prefix, word;
    #
    # whitespace := " ";
    # other_chars := {JSON_char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    # word_forms := whitespace | variable_prefix | word | other_chars;
    # string := {word_forms};
    #
    # true := JSON_true;
    # false := JSON_false;
    # boolean = true | false;
    #
    # number := JSON_number;
    # null := JSON_null;
    # value := variable_identifier | string | number | boolean |
    #          boolean | null | array | single;
    #
    # array_start := "[";
    # array_end := "]";
    # comma := ",";
    # element_more := {comma, value}
    # element_list := value, element_more    
    # array := array_start, [element_list], array_end;
    #
    # let := "let";
    # ref := "ref";
    # doc := "doc";
    # unknown_special_form := {JSON_char};
    # proc_prefix := "&";
    # special_form := let | ref | doc | unknown_special_form;
    # procedure := proc_prefix, special_form;
    #
    # colon := ":";
    # call_value := array | null | single;
    # call := procedure, colon, call_value;
    #
    # program_start := "{";
    # program_end := "}";
    # single := program_start, call, program_end;
    #
    # key_word := {JSON_char}; (*all characters excluding proc_prefix*)
    # attribute := key_word, colon, value;
    #
    # pair := call | attribute;
    # declaration_more := comma, pair;
    # declaration_list := pair, {declaration_more};
    # program := program_start, [declaration_list], program_end;
    def initial
      rules = {program: program_rule,
               declaration: declaration_rule,
               declaration_list: declaration_list_rule,
               pair: pair_rule,
               call: call_rule,
               call_value: call_value_rule,
               procedure: procedure_rule,
               special_form: special_form_rule,
               value: value_rule,
               boolean: boolean_rule,
               variable_identifier: variable_identifier_rule,
               array: array_rule,
               array_list: array_list_rule,
               attribute: attribute_rule,
               single: single_rule}
      L0 = Struct.new *rules.keys
      L0.new *rules.values
    end

    private
   
    def boolean_rule
      Rule[:boolean, Array.new.push(Terminal[:true, :choice])
                     .push(Terminal[:false, :choice])]
    end
    
    def variable_identifier_rule
      Rule[:variable_identifier, Array.new.push(Terminal[:variable_prefix])
                                 .push(Terminal[:word])]
    end
  end
end
