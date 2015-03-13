require_relative './formal_languages'

module Eson
  class AbstractSyntaxTree

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
  end
end
