require 'forwardable'
require_relative './typed_seq'

module Eson

  class Rule

    class AbstractSyntaxTree
      CannotConvertTypeToTree = Class.new(StandardError)
      UnallowedMethodForClosedTree = Class.new(StandardError)
      
      extend Forwardable
      include LexemeCapture

      attr_reader :height

      #Initialize tree with obj as root node. An empty
      #tree is created if no parameter is given.
      #@param obj [Eson::Rule] Rule
      def initialize(obj=nil)
        init_empty
        set_root(obj)
      end

      def init_empty
        @height = 0
        @root_tree = @active = Tree.new
      end

      def set_root(obj)
        unless obj.nil?      
          @root_tree = @active = convert_to_tree(obj)
          @height = 1
          if obj.instance_of?(Token)
            close_active
          end
        end
      end

      #Converts Rule or Token to a Tree
      #@param obj [Rule, Token] the Rule or Token to be converted
      #@return [Eson::Rule::AbstractSyntax::Tree] the resulting tree
      #@raise [CannotConvertTypeToTree] if the object is neither
      #  a Token or a nonterminal Rule
      def convert_to_tree(obj)
        if obj.instance_of?(Token)
          make_leaf(obj)
        elsif obj.instance_of?(Rule) && obj.nonterminal?
          make_tree_node(obj)
        else
          raise CannotConvertTypeToTree,
                invalid_input_type_error_message(obj)
        end
      end

      def make_leaf(token)
        tree = Tree.new(token, TreeSeq.new, active_node, false)
               .set_level
      end

      def make_tree_node(rule)
        tree = Tree.new(rule, TreeSeq.new, active_node, true)
               .set_level
      end
      
      #Insert an object into the active tree node. Tokens are
      #added as leaf nodes and Rules are added as the active tree
      #node.
      #@param obj [Token, Rule] eson token or production rule
      #@raise [UnallowedMethodForClosedTree] If the tree is closed
      def insert(obj)
        if empty_tree?
          set_root(obj)
        else
          ensure_open
          new_tree = convert_to_tree(obj)
          active_node.children.push new_tree
          update_height(new_tree)
          if obj.instance_of? Rule
            @active = new_tree
          end
        end
        self
      end
      
      def update_height(tree)
        if tree.level > @height
          @height = tree.level
        end
      end
      
      def invalid_input_type_error_message(obj)
        "The class #{obj.class} of '#{obj}' is not a" \
        " valid input for the #{self.class}. Input" \
        " must be a #{Token} or a nonterminal #{Rule}."
      end

      #Add a given tree to this tree's active node
      #@param tree [Eson::Rule::AbstractSyntaxTree]
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
      #@return [Eson::Rule::AbstractSyntaxTree::Tree] the active tree node
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
      #@return [Eson::Rule::AbstractSyntaxTree]
      def close_active
        new_active = @active.parent
        @active.close
        unless new_active.empty_tree?
          @active = new_active
        end
        self
      end

      def_delegators :@root_tree, :root_value, :degree, :closed?,
                     :open?, :leaf?, :ensure_open, :has_child?,
                     :has_children?, :rule, :children, :level,
                     :empty_tree?, :contains?

      #Struct class for a tree node
      Tree = Struct.new :value, :children, :parent, :open_state, :level do
        
        #The value of the root node
        #@return [Eson::Rule]
        def root_value
          value
        end
        
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
          leaf? ? 0 : children.length
        end

        def leaf?
          children.nil? || children.empty?
        end

        def empty_tree?
          value.nil?
        end

        def ensure_open
          if closed?
            raise UnallowedMethodForClosedTree,
                  closed_tree_error_message
          end
        end

        def closed_tree_error_message
          "The method `#{caller_locations(3).first.label}'" \
          " is not allowed on a closed tree."
        end

        #@param name [Symbol] name of child node
        def has_child?(name)
          children.detect{|i| i.value.name == name} ? true : false
        end

        #@param names [Array<Symbol>] ordered list of the
        #names of child nodes
        def has_children?(names)
          names == children.map{|i| i.value.name}
        end

        #Search tree for the presence of a value
        #@param name [Symbol] name of child node
        #@return [Boolean] true if the name is present
        def contains?(name)
          root_match = root_value.name == name
          if root_match || has_child?(name)
            true
          else
            children.any?{|i| i.contains?(name)}
          end
        end

        #@param offset [Integer]
        def set_level(offset=0)
          self.level = parent.empty_tree? ? 1 : 1 + parent.level
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

      TreeSeq = TypedSeq.new_seq(Tree)
    end
  end
end
