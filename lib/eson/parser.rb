require_relative 'language.rb'
module Eson
  
  module Parser

    extend Eson::Language
    extend self

    #Parse tokens into abstract syntax tree
    #@param token_sequence [Array] the eson token sequence
    #@return [AbstractSyntaxTree] AbstractSyntaxTree of token sequence
    #@eskimobear.specification
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
    #        OR A' = A + tree_insert(et) otherwise
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
      language = Eson::Language.initial
    end

    def lookahead(token_sequence)
      token_sequence.first
    end

    def unparsed_sequence(token_sequence)
      token_sequence.drop(1)
    end

    def valid_start?(token, rule)
      rule_regex.first_regex
      token.lexeme.to_s.match(rule_regex).nil? ? false : true
    end

  end
end
