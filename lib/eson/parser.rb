module Eson
  
  module Parser

    extend self

    #Parse tokens into abstract syntax tree
    #
    #Returns an array of syntax structs [[declaration, type]]
    #@param token_sequence [Array] the eson token sequence
    #@return [Hash] abstract syntax tree
    #@eskimobear.specification
    #The following EBNF rules describe the eson grammar. 
    #---EBNF
    #program = program_start, [declaration], program_end, [end_of_file];
    #
    #declaration = pair, declaration_list;
    #declaration_list = {comma, pair};
    #pair = call | attribute;
    #
    #(*a call is a declaration performing procedure application without
    #  direct substitution*)
    #call = procedure, colon, array | null | single;
    #
    #procedure = proc_prefix, special_form; 
    #
    #special_form = let | ref | doc | unknown_special_form;
    #
    #value = variable_identifier | string | single | document | number |
    #        array | true | false | null;
    #
    #(*a variable_identifier is a string that can be dereferenced to a value held 
    #  in the value store*)
    #variable_identifier = variable_prefix, word;
    #
    #string = [whitespace | variable_prefix], [word | other_chars],
    #         {[whitespace | variable_prefix], [word | other_chars]};
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
    #---EBNF
    def generate_ast(token_sequence)
    end

  end
end
