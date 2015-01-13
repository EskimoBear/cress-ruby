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
    #call = procedure, colon, call_value;
    #call_value = array | null | single;
    #
    #procedure = proc_prefix, special_form; 
    #
    #special_form = let | ref | doc | unknown_special_form;
    #
    #value = variable_identifier | string | single | number |
    #        array | boolean | null;
    #boolean = true | false;
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
    #
    # T, is the token sequence
    # et, is a token in T
    # U, is the unparsed token sequence
    # A, is the abstract syntax tree
    # p, is a production rule
    # p_a, is a nested nonterminal in p
    # r, is a legal token sequence for p or p_a
    # r0, is the first token of r
    # rn, is the last token of r
    # s0, is the first token of the sequence following r
    # p_first, is the set of legal r0 for r
    # p_follow, is the set of legal s0 following r
    #
    # Init : degree(A) = 0
    #      : U = T
    #        
    # Next : U' = U - et
    #      : A' = A + tree_insert(p), when et=r0
    #      : A' = A + tree_insert(et) otherwise
    #
    #  Call top production rule parser with U
    #  Inspect next
    #  If next is in p_first
    #  insert production rule in A
    #    if next of U is rn
    #      if U - rn is the empty sequence
    #        return A and U - rn
    #      if U - rn is not an empty sequence
    #      Throw a syntax error
    #    if next is in p_first of a nested nonterminal rule, p_a
    #      call production rule parser for p_a with A and U - r0
    #      return A and U
    #      if next of U is in p_follow of p_a
    #        if next of U is et
    #        if et is a member of r
    #          insert token in A
    #          return A and U - et
    #        if et is not a member of r
    #          Throw a syntax error
    #    else if U is not in p_follow of p_a
    #      Throw a syntax error
    #  If next is not in p_first
    #  Throw a syntax error
    def generate_ast(token_sequence)
    end

  end
end
