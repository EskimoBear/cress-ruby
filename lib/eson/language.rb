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
    # boolean := true | false;
    #
    # number := JSON_number;
    # null := JSON_null;
    # value := variable_identifier | string | number | boolean |
    #          null | array | single;
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
    # declaration_more := {comma, pair};
    # declaration_list := pair, declaration_more;
    # program := program_start, [declaration_list], program_end;
    def initial
      rules = {variable_identifier: variable_identifier_rule,
               word_form_rules: word_form_rule,
               string: string_rule,
               boolean: boolean_rule,
               value: value_rule,
               element_more: element_more_rule,
               element_list: element_list_rule,
               array: array_rule,
               special_form: special_form_rule,
               procedure: procedure_rule,
               call_value: call_value_rule,
               call: call_rule,
               single: single_rule,
               attribute: attribute_rule,
               pair: pair_rule,
               declaration_more: declaration_more_rule,
               declaration_list: declaration_list_rule,
               program: program_rule}
      initial_language = Struct.new *rules.keys
      initial_language.new *rules.values
    end
    
    private

    # variable_identifier := variable_prefix, word;
    def variable_identifier_rule
      Rule.new(:variable_identifier,
               [Terminal[:variable_prefix],
                Terminal[:word]])
    end

    # word_forms := whitespace | variable_prefix | word | other_chars;
    def word_forms_rule
      Rule.new(:word_forms,
               [Terminal[:whitespace, :choice],
                Terminal[:variable_prefix, :choice],
                Terminal[:word, :choice],
                Terminal[:other_chars, :choice]])
    end

    # string := {word_forms};
    def string_rule
      Rule.new(:string,
               [NonTerminal[:word_forms, word_forms_rule, :repetition]])
    end

    # boolean := true | false;  
    def boolean_rule
      Rule.new(:boolean,
               [Terminal[:true, :choice],
                Terminal[:false, :choice]])
    end

    # value := variable_identifier | string | number | boolean |
    #          null | array | single;
    def value_rule
      Rule.new(:value_rule,
               [NonTerminal[:variable_identifier, variable_identifier_rule, :choice],
                NonTerminal[:string, string_rule, :choice],
                Terminal[:number, :choice],
                NonTerminal[:boolean, boolean_rule, :choice],
                Terminal[:null, :choice],
                NonTerminal[:array, array_rule, :choice],
                NonTerminal[:single, single_rule, :choice]])
    end
    
    # element_more := {comma, value}
    def element_more_rule
      Rule.new(:element_more,
               [Terminal[:comma, :repetition],
                NonTerminal[:value, value_ray, :repetition]])
    end
    
    # element_list := value, element_more
    def element_list_rule
      Rule.new(:element_list,
               [NonTerminal[:value, value_rule],
                NonTerminal[:element_more, element_more]])
    end
    
    # array := array_start, [element_list], array_end;
    def array_rule
      Rule.new(:array,
               [Terminal[:array_start],
                NonTerminal[:element_list, element_list_rule, option],
                Terminal[:array_end]])
    end
    
    # special_form := let | ref | doc | unknown_special_form;
    def special_form_rule
      Rule.new(:special_form,
               [Terminal[:let, :choice],
                Terminal[:ref, :choice],
                Terminal[:doc, :choice],
                Terminal[:unknown_special_form, :choice]])
    end
    
    # procedure := proc_prefix, special_form;
    def procedure_rule
      Rule.new(:procedure,
               [Terminal[:proc_prefix],
                NonTerminal[:special_form, special_form_rule]])
    end

    # call_value := array | null | single;
    def call_value
      Rule.new(:call_value,
               [Terminal[:null, :choice],
                NonTerminal[:array, array_rule, :choice],
                NonTerminal[:single, single_rule, :choice]])
    end
    
    # call := procedure, colon, call_value;
    def call_rule
      Rule.new(:call,
               [NonTerminal[:procedure, procedure_rule],
                Terminal[:colon],
                NonTerminal[:call_value, call_value_rule]])
    end

    # single := program_start, call, program_end;
    def single_rule
      Rule.new(:single,
               [Terminal[:program_start],
                NonTerminal[:call, call_rule],
                Terminal[:program_end]])
    end
    
    # attribute := key_word, colon, value;
    def attribute_rule
      Rule.new(:attribute,
               [Terminal[:key_word],
                Terminal[:colon],
                NonTerminal[:value, value_rule]])
    end
    
    # pair := call | attribute;
    def pair_rule
      Rule.new(:pair,
               [NonTerminal[:call, call_rule, :choice],
                NonTerminal[:attribute, attribute_rule, :choice]])
    end
    
    # declaration_more := {comma, pair};
    def declaration_more_rule
      Rule.new(:declaration_more,
               [Terminal[:comma, :repetition],
                NonTerminal[:pair, pair_rule, :repetition]])
    end

    # declaration_list := pair, declaration_more;
    def declaration_list_rule
      Rule.new(:declaration_list,
               [NonTerminal[:pair, pair_rule],
                NonTerminal[:declaration_more, declaration_more_rule]])
    end
    
    # program := program_start, [declaration_list], program_end;
    def program_rule
      Rule.new(:program,
               [Terminal[:program_start],
                NonTerminal[:declaration_list, declaration_list_rule, option],
                Terminal[:program_end]])
    end
  end
end
