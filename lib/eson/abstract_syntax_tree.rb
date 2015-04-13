require 'forwardable'

module Eson
  module Language

    class AbstractSyntaxTree
      InsertionError = Class.new(StandardError)
      ClosedTreeError = Class.new(StandardError)
      ChildInsertionError = Class.new(StandardError)
      InitializationError = Class.new(StandardError)

      extend Forwardable

      Token = Eson::Language::LexemeCapture::Token
      Rule = Eson::Language::Rule

      attr_reader :height

      #Initialize tree with obj as root node. An empty
      #tree is created if no parameter is given.
      #@param obj [Eson::Language::Rule] Rule
      #@raise [InsertionError] obj is not a valid type
      #for the root node
      def initialize(obj=nil)
        insert_root(obj)
      rescue InsertionError => e
        raise InitializationError,
              not_a_valid_root_error_message(obj)
      end

      def insert_root(obj)
        if obj.nil?
          @root_tree = @active = nil
        elsif obj.instance_of? Token
          @root_tree = @active = make_leaf(obj)
          @height = 1
          close_active
        elsif obj.instance_of?(Rule) && obj.nonterminal?
          @root_tree = @active = make_tree(obj)
          @height = 1
        else
          raise InsertionError, not_a_valid_input_error_message(obj)
        end
      end

      def make_tree(rule)
        tree = Tree.new(rule, TreeSeq.new, active_node, true)
               .set_level
      end


      def make_leaf(token)
        tree = Tree.new(token, nil, active_node, false)
               .set_level
      end

      def not_a_valid_root_error_message(obj)
        "The class #{obj.class} of '#{obj}' cannot be used as a root
         node for #{self.class}. Parameter must be either a #{Token} 
         or a nonterminal #{Rule}."
      end
      
      def empty?
        @root_tree.nil?
      end
         
      #Insert an object into the active tree node. Tokens are
      #added as leaf nodes and Rules are added as the active tree
      #node.
      #@param obj [Token, Rule] eson token or production rule
      #@raise [InsertionError] If obj is neither a Token or Rule
      #@raise [ClosedTreeError] If the tree is closed
      def insert(obj)
        if empty?
          insert_root(obj)
        else
          ensure_open
          if obj.instance_of? Token
            insert_leaf(obj)
          elsif obj.instance_of? Rule
            insert_tree(obj)
          else
            raise InsertionError, not_a_valid_input_error_message(obj)
          end
        end
        self
      end

      def insert_leaf(token)
        leaf = make_leaf(token)
        active_node.children.push leaf
        update_height(leaf)
      end

      def update_height(tree)
        if tree.level > @height
          @height = tree.level
        end
      end

      def insert_tree(rule)
        tree = make_tree(rule)
        active_node.children.push tree
        update_height(tree)
        @active = tree
      end

      def not_a_valid_input_error_message(obj)
                "The class #{obj.class} of '#{obj}' is not a valid input for the #{self\
.class}. Input must be a #{Token}."
      end

      #Add a given tree to this tree's active node
      #@param tree [Eson::Language::AbstractSyntaxTree]
      #@raise [MergeError] if tree is not closed before merging
      def merge(tree)
        if tree.closed?
          tree.get.increment_levels(active_node.level)
          possible_height = tree.height + active_node.level
          @height = @height < possible_height ? possible_height : @height
          @active.children.push(tree.get)
          self
        end
      end

      #Get the active node of the tree. This is the open tree node to
      #the bottom right of the tree i.e. the last inserted tree node.
      #@return [Eson::Language::AbstractSyntaxTree::Tree] the active tree node
      def active_node
        @active
      end

      def get
        @root_tree
      end

      def close_tree
        @root_tree.open_state = false
        self
      end

      #Closes the active node of the tree and makes the next
      #open ancestor the active node.
      #@return [Eson::Language::AbstractSyntaxTree]
      def close_active
        new_active = @active.parent
        @active.close
        unless new_active.nil?
          @active = new_active
        end
        self
      end

      def_delegators :@root_tree, :root_value, :degree, :closed?,
                     :open?, :leaf?, :ensure_open, :has_child?,
                     :has_children?, :rule, :children, :level

      #Struct class for a tree node
      Tree = Struct.new :value, :children, :parent, :open_state, :level do

        #The value of the root node
        #@return [Eson::Language::Rule]
        def root_value
          value
        end

        #Close the active node of the tree and make parent active.
        def close
          self.open_state = false
        end

        #The open state of the tree.
        #@return [Boolean]
        def open?
          open_state
        end

        def closed?
          !open?
        end

        def degree
          children.length
        end

        def leaf?
          children.nil? || children.empty?
        end

        def ensure_open
          if closed?
            raise ClosedTreeError, closed_tree_error_message
          end
        end

        def closed_tree_error_message
                    "The method `#{caller_locations(3).first.label}' is not allowed on a \
closed tree."
        end

        #@param name [Symbol] name of child node
        def has_child?(name)
          children.detect{|i| i.value.name == name} ? true : false
        end

        #@param names [Array<Symbol>] ordered list of the names of child nodes
        def has_children?(names)
          names == children.map{|i| i.value.name}
        end

        #@param offset [Integer]
        def set_level(offset=0)
          self.level = parent.nil? ? 1 : 1 + parent.level
          self.level = level + offset
          self
        end

        #Increment the tree levels of a given tree
        #@param offset [Integer]
        def increment_levels(offset)
          set_level(offset)
          unless leaf?
            children.each{|t| t.set_level}
          end
        end
      end

      class TreeSeq < Array

        Tree = Eson::Language::AbstractSyntaxTree::Tree

        pushvalidate = Module.new do
          def push(obj)
            if obj.instance_of? Tree
              super
            else
              raise ChildInsertionError, not_a_valid_node_error_message(obj)
            end
          end
        end

        prepend pushvalidate

        def not_a_valid_node_error_message(obj)
                    "The class #{obj.class} of '#{obj}' is not a valid node for the #{sel\
f.class}. The object must be a #{Tree}."
        end
      end
    end
  end
end
