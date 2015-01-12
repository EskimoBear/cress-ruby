module Eson

  module Language
    extend self

    #Return the initial formal language of the compiler
    #@return [Language] the initial eson language as a Struct
    #@eson.specification
    #
    #A Language is a struct of production rules
    #A Rule or production rule is a struct of type and concatenation
    #A concatenation is an array of NonTerminals and Terminals
    #Terminals are structs with type, lexeme and operation
    #NonTerminals are structs with type, rule_type and operation
    #operation is an enum of either :alternation, :option or :repetition as
    # defined by EBNF
    #the concatenation rule operation is implicit in the ordering of
    #  concatenation
    #
    #The following EBNF rules describe the eson grammar. 
    #---EBNF
    #program = program_start, [declaration], program_end, [end_of_file];
    #
    #program_start = "{";
    #program_end = "}";
    #end_of_file = EOF;
    #
    #declaration = pair, declaration_list;
    #declaration_list = {comma, pair};
    #
    #pair = call | attribute;
    #comma = ",";
    #
    #(*a call is a declaration performing procedure application without
    #  direct substitution*)
    #call = procedure, colon, call_value;
    #call_value = array | null | single;
    #
    #procedure = proc_prefix, special_form; 
    #proc_prefix = "&";
    #special_form = let | ref | doc | unknown_special_form;
    #let = "let";
    #ref = "ref";
    #doc = "doc";
    #unknown_special_form = {char};
    #colon = ":";
    #
    #value = variable_identifier | string | single | number |
    #        array | true | false | null;
    #boolean = true | false;
    #
    #(*a variable_identifier is a string that can be dereferenced to a value held 
    #  in the value store*)
    #variable_identifier = variable_prefix, word;
    #variable_prefix = "$";
    #
    #string = [whitespace | variable_prefix], [word | other_chars],
    #         {[whitespace | variable_prefix], [word | other_chars]};
    #whitespace = " ";
    #word = {char}; (*letters, numbers, '-', '_', '.'*)
    #other_chars = {char}; (*characters excluding those found
    #   in variable_prefix, word and whitespace*)
    #
    #array = array_start, value, array_list, array_end;
    #array_list = {comma, value}
    #
    #(*an attribute performs simultaneous variable and
    # value creation*)
    #attribute = key_word, colon, value;
    #key_word = {char} (*all characters excluding proc_prefix*)
    #
    #(*a single is a program allowing
    # procedure application and substitution*)
    #single = program_start, call, program_end;
    #
    #prefix = proc_prefix | variable_prefix;
    #---EBNF
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
    end
  end
end
