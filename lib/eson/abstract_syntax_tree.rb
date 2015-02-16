require 'pry'

require 'forwardable'
require_relative './language'
require_relative './tokenizer'

module Eson
  
  #Class contains tree operations for stuct based trees that
  #conform to the following properties. 
  #Properties of the tree A, abstract syntax tree 
  # Prop : An eson token is added to A as a leaf node.
  #      : An production rule is added to A as a tree node.
  #      : A tree node is marked complete if it contains a
  #        full symbol with respect to the next token tried
  #        for insertion.
  #      : A node is added to the first incomplete tree node
  #        where it is a valid next member. Insertion begins
  #        at the complete nodes from the bottom right of the
  #        tree going up to it's parent.
  class AbstractSyntaxTree
    
    TreeInsertionError = Class.new(StandardError)
    TreeSeqInsertionError = Class.new(StandardError)
    TreeInitializationError = Class.new(StandardError)

    extend Forwardable

    Token = "Eson::Tokenizer::TokenSeq::Token"
    Rule = "Eson::Language::RuleSeq::Rule"

    class TreeSeq < Array

      Tree = "Eson::AbstractSyntaxTree::Tree"
      
      pushvalidate = Module.new do
        def push(obj)
          case obj.class.to_s
          when Token
            super
          when Tree
            super
          else
            raise TreeSeqInsertionError, not_a_valid_node_error_message(obj)
          end
        end
      end

      prepend pushvalidate

      def not_a_valid_node_error_message(obj)
        "The class #{obj.class} of '#{obj}' is not a valid node for the #{self.class}. Must be either a #{Token} or a #{Rule}."
      end
    end
        
    Tree = Struct.new :rule, :children do
      
      def add_node(node)
        case node.class.to_s
        when Rule
          tree = Eson::AbstractSyntaxTree::Tree.new(node, TreeSeq.new)
          self.children.push(tree)
        when Token
          if valid_token? node
            self.children.push(node)
          else
            raise TreeInsertionError, not_a_valid_token_error_message(node)
          end
        else #raise error
          self.children.push(node)
        end
      end

      def valid_token?(token)
        self.rule.contains_terminal? token.name
      end

      def degree
        self.children.length
      end

      def not_a_valid_token_error_message(token)
        "The token #{token.name} does not constitute legal syntax in any available position."
      end
    end

    #Initialize tree with the main production rule of a formal language
    #@param language [Eson::Language::e0] eson formal language
    def initialize(language)
      if language.respond_to?(:top_rule)
        @language = language
        @tree = Eson::AbstractSyntaxTree::Tree.new(language.top_rule, TreeSeq.new)
      else
        raise TreeInitializationError, not_a_valid_language_error_message(language)
      end
    end
    
    def not_a_valid_language_error_message(language)
      "'#{language.class}' is not a valid language for #{self.class}."
    end

    def get
      @tree
    end

    def_delegators :@tree, :rule, :children, :add_node, :degree
  end
end

