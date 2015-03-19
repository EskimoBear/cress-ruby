require 'forwardable'
require_relative './formal_languages'

module Eson

  module Language

    include Eson::Language::LexemeCapture

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

      Token = Eson::Language::LexemeCapture::Token
      Rule = Eson::Language::RuleSeq::Rule

      #Initialize tree with given Rule as root node.
      #@param language [Eson::Language::RuleSeq::Rule] Rule
      def initialize(rule)
        if rule.instance_of? Rule
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
        if obj.instance_of? Eson::Language::LexemeCapture::Token
          insert_leaf(obj)
        elsif obj.instance_of? Rule
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

            #Struct class for a tree node
      Tree = Struct.new :rule, :children, :open_state do

        #The value of the root node
        #@return [Eson::Language::RuleSeq::Rule]
        def root_value
          rule
        end

        #The open state of the root node. A child node
        #can only be inserted into an open node.
        #@return [Boolean]
        def open?
          open_state
        end

        def closed?
          !open?
        end

        def empty?
          children.empty?
        end 
      end

            class TreeSeq < Array

        Tree = Eson::Language::AbstractSyntaxTree::Tree
        
        pushvalidate = Module.new do
          def push(obj)
            if obj.instance_of? Token
              super
            elsif obj.instance_of? Tree
              super
            else
              raise TreeSeqInsertionError, not_a_valid_node_error_message(obj)
            end
          end
        end

        prepend pushvalidate

        def not_a_valid_node_error_message(obj)
          "The class #{obj.class} of '#{obj}' is not a valid node for the #{self.class}. Must be either a #{Token} or a #{Tree}."
        end
      end
    end
  end
end
