require_relative 'language.rb'
module Eson
  
  module Parser

    extend self

    #Parse tokens into abstract syntax tree
    #@param token_sequence [Array] the eson token sequence
    #@return [Eson::AbstractSyntaxTree] AbstractSyntaxTree of token sequence
    #@eskimobear.specification
    # A, is the abstract syntax tree with root p_top
    # U, is the unparsed token sequence
    # et, is a token in U
    # T, is the token sequence
    # p, is a production rule
    # E, is the set of error tokens
    #
    # Init : degree(A) = 0
    #      : length(E) = 0
    #      : U = T
    #
    # Next : et = next(U)         
    #      : when valid_next?(A) = et
    #          A' = tree_insert(A, et)
    #          U' = U - et
    #      : when valid_next?(A) = p
    #          A' = tree_insert(A, p)
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
