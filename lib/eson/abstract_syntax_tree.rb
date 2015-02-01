require 'pry'

require 'forwardable'
require_relative './language'
require_relative './tokenizer'

module Eson

  TreeInsertionError = Class.new(StandardError)
  TreeInitializationError = Class.new(StandardError)
  
  #Class contains tree operations for stuct based trees that
  #conform to the following properties. 
  #Properties of the tree A, abstract syntax tree 
  # Prop : an eson token is added to A as a leaf node
  #      : an production rule is added to A as a tree
  #
  #      : A tree has rule and children
  #      : A node is a production rule each sub-tree belongs to a
  #          valid token sequence or the rule.
  #      : Sub-trees are ordered by insertion order, earliest insertion
  #          is leftmost
  class AbstractSyntaxTree

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
            raise TreeInsertionError, Eson::AbstractSyntaxTree.not_a_valid_node_error_message(obj)
          end
        end
      end

      prepend pushvalidate
    end
        
    Tree = Struct.new :rule, :children do
      
      def add_node(node)
        case node.class.to_s
        when Rule
          tree = Eson::AbstractSyntaxTree::Tree.new(node, TreeSeq.new)
          self.children.push(tree)
        else
          self.children.push(node)
        end
      end

      def degree
        self.children.length
      end
    end

    def initialize(language)
      if language.respond_to?(:top_rule)
        @language = language
        @tree = make_root_node
      else
        raise TreeInitializationError, not_a_valid_language_error_message(language)
      end
    end

    def make_root_node
      Eson::AbstractSyntaxTree::Tree.new(@language.top_rule, TreeSeq.new)
    end
    
    def not_a_valid_language_error_message(language)
      "'#{language.class}' is not a valid language for #{self.class}."
    end

    def self.not_a_valid_node_error_message(obj)
      "The class #{obj.class} of '#{obj}' is not a valid node for the #{self}. Must be either a #{Token} or a #{Rule}."
    end

    def get
      @tree
    end

    def_delegators :@tree, :rule, :children, :add_node, :degree
  end
end

