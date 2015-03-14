require 'pry'

require 'forwardable'
require_relative './language'
require_relative './tokenizer'
require_relative './tree_seq'

module Eson

  module Language

    extend self
    #Class contains tree operations for stuct based trees that
    #conform to the following properties. 
    #Properties of the tree A, abstract syntax tree 
    # Prop : The tree has a single active node. This is the
    #        open tree node to the bottom right of the tree. If
    #        this tree node is closed, the active node is it's
    #        next open ancestor.
    class AbstractSyntaxTree
      
      TreeInsertionError = Class.new(StandardError)
      TreeSeqInsertionError = Class.new(StandardError)
      TreeInitializationError = Class.new(StandardError)

      extend Forwardable

      Token = "Eson::Tokenizer::TokenSeq::Token"
      Rule = "Eson::Language::RuleSeq::Rule"

      #Initialize tree with given Rule as root node.
      #@param language [Eson::Language::RuleSeq::Rule] Rule
      def initialize(rule)
        if rule.class.to_s == Rule
          @root_tree = Tree.new(rule, TreeSeq.new, true)
          @active = @root_tree
        else
          raise TreeInitializationError,
                not_a_rule_error_message(rule)
        end
      end
      
      def not_a_rule_error_message(obj)
        "'#{obj.class}' is not a valid root for #{self.class}. Please provide a #{Rule}"
      end

      #Insert an object into the active tree node. Tokens are
      #added as leaf nodes and Rules are added as the active tree
      #node. Insertion fails for other types.
      #@param [Token, Rule] eson token or production rule
      def insert(obj)
        case obj.class.to_s
        when Token
          insert_leaf(obj)
        when Rule
          insert_tree(obj)
        else
          raise TreeInsertionError, not_a_valid_input_error_message(obj)
        end
      end

      def insert_leaf(token)
        active_node.children.push(token)
      end

      def insert_tree(rule)
        tree = Tree.new(rule, TreeSeq.new, true)
        active_node.children.push(tree)
        @active = tree
      end

      def not_a_valid_input_error_message(obj)
        "The class #{obj.class} of '#{obj}' is not a valid input for the #{self.class}. Input must be a #{Token}."
      end
      
      #Get the active node of the tree. This is the open tree node to
      #the bottom right of the tree. If this tree node is closed, the
      #active node is it's next open ancestor.  
      #@return [Eson::AbstractSyntaxTree::Tree] the active tree node
      def active_node
        @active
      end

      def get
        @root_tree
      end

      def_delegators :@root_tree, :root_value, :closed?, :open?, :empty?,
                     :rule, :children
    end
  end
end
