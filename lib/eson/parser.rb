require_relative 'language.rb'
module Eson
  
  module Parser

    extend self

    #Parse tokens into abstract syntax tree
    #@param token_sequence [Array] the eson token sequence
    #@return [Eson::AbstractSyntaxTree] AbstractSyntaxTree of token sequence
    #@eskimobear.specification
    # L, an eson formal language
    # p_top, main production rule of L
    # T, is the token sequence
    # et, is a token in T
    # U, is the unparsed token sequence
    # A, is the abstract syntax tree for L
    # p, is the current production rule
    # E, is the set of error tokens
    # f_t, is the set of legal tokens that can appear at the
    #    start of an unexpanded production rule
    # p_fn, is the first nested rule of p
    # p_n, is a nested rule of p
    # p_nt, is a nonterminal symbol in the definition of p
    # p_t, is a terminal symbol in the definition p
    # p_par, is the list of parent rules of p
    #
    # Init : degree(A) = 0
    #      : length(E) = 0
    #      : U = T
    #      : p = p_top
    #      : length(p_par) = 0
    #
    # Next : U' = U - et
    #      : when p.complete?(et) = true
    #          p_par' = p_par + p
    #          p' = rule_start?(et)
    #      : when rule_start?(et) = p
    #          when f_t(p) != []
    #            when et is member of f_t(p)
    #              A' = A + tree_insert(et)
    #            otherwise
    #              E' = E + et
    #          when f_t(p) = []
    #            p_par' = p_par + p
    #            p' = p_fn
    #            A' = A + tree_insert(p')
    #      : when p.next?(et) = true
    #          when p.next? = p_n
    #            p_par' = p
    #            p' = p_n
    #          when p.next? = p_t
    #            A' = A + tree_insert(et)
    #      : when p.next?(et) = false
    #          when p_par = []
    #            E' = E + et
    #          otherwise
    #            p' = last(p_par)
    #            p_par' = p_par - p'
    #      : otherwise
    #          E' = E + et    
    def generate_ast(token_sequence)
    end

    def lookahead(token_sequence)
      token_sequence.first
    end

    def rest_of_tokens(token_sequence)
      token_sequence.drop(1)
    end

  end
end
