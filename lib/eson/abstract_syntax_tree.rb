require 'pry'

require 'forwardable'
require_relative './language'
require_relative './tokenizer'

module Eson
  
  #Class contains tree operations for stuct based trees that
  #conform to the following properties. 
  #Properties of the tree A, abstract syntax tree 
  # Prop : An eson token is added to A as a leaf node.
  #      : An production rule is added to A as a tree node
  #        with open status.
  #      : A tree node is marked closed if it contains a
  #        full symbol with respect to the next token tried
  #        for insertion.
  #      : The tree has a single active node. This is the
  #        open tree node to the bottom right of the tree. If
  #        this tree node is closed, the active node is it's
  #        next open ancestor.
  #      : A node is added to the active node if is a valid
  #        next child node. If the node is not a valid next
  #        child node insertion fails.
  class AbstractSyntaxTree
    
    TreeInsertionError = Class.new(StandardError)
    TreeSeqInsertionError = Class.new(StandardError)
    TreeInitializationError = Class.new(StandardError)

    extend Forwardable

    Token = "Eson::Tokenizer::TokenSeq::Token"
    Rule = "Eson::Language::RuleSeq::Rule"

    #Struct class for a tree node
    Tree = Struct.new :rule, :children, :open_state do

      #The value of the root node
      #@return [Eson::Language::RuleSeq::Rule]
      def root_value
        rule
      end

      #The open state of the root node. A node is open
      #if it is possible to add another child node.
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
        else
          raise TreeInsertionError, not_a_valid_node_type_error_message(node)
        end
      end

      def valid_token?(token)
        self.rule.contains_terminal? token.name
      end

      def degree
        self.children.length
      end

      def not_a_valid_token_error_message(token)
        "The token #{token.name} does not constitute legal syntax in the available position."
      end

      def not_a_valid_node_type_error_message(node)
        "The class #{node.class} of '#{node}' is not a valid node for the #{self.class}. Must be either a #{Token} or a #{Rule}."
      end
    end
    
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
        "The class #{obj.class} of '#{obj}' is not a valid node for the #{self.class}. Must be either a #{Token} or a #{Tree}."
      end
    end

    #Initialize tree with the main production rule of a
    #formal language
    #@param language [Eson::Language::e0] formal language
    def initialize(language)
      if language.respond_to?(:top_rule)
        @language = language
        @tree = Eson::AbstractSyntaxTree::Tree
                .new(language.top_rule, TreeSeq.new, true)
        @active = @tree
      else
        raise TreeInitializationError,
              not_a_valid_language_error_message(language)
      end
    end
     
    def not_a_valid_language_error_message(language)
      "'#{language.class}' is not a valid language for #{self.class}."
    end

    #Get the active node of the tree. This is the open tree node to
    #the bottom right of the tree. If this tree node is closed, the
    #active node is it's next open ancestor.  
    #@return [Eson::AbstractSyntaxTree::Tree] the active tree node
    def active_node
      @active
    end

    def get
      @tree
    end

    def_delegators :@tree, :root_value, :closed?, :open?, :empty?, :rule, :children, :add_node, :degree
  end
end

