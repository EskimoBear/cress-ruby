require 'forwardable'
require_relative './typed_seq'
require_relative './attribute_actions'

module Eson

  class Rule

    class ParseTree
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
        if token.attributes.nil?
          attributes = {:s_attr => {}}
        else
          attributes = {:s_attr => token.attributes}
        end
        attributes[:s_attr].update({:lexeme => token.lexeme})
        tree = Tree.new(token, TreeSeq.new, active_node, false)
               .init_attributes(attributes)
               .set_name(token.name)
               .set_level
      end

      def make_tree_node(rule)
        tree = Tree.new(rule, TreeSeq.new, active_node, true)
               .build_s_attributes(rule.s_attr)
               .build_i_attributes(rule.i_attr)
               .set_name(rule.name)
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
      #@param tree [Eson::Rule::ParseTree]
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
      #@return [Eson::Rule::ParseTree::Tree] the active tree node
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
      #@return [Eson::Rule::ParseTree]
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
                     :empty_tree?, :contains?, :attribute_list,
                     :get_attribute, :store_attribute, :bottom_left_node,
                     :post_order_trace, :post_order_traversal,
                     :attributes, :name

      #Struct class for a tree node
      Tree = Struct.new :value, :children, :parent, :open_state,
                        :level, :name, :attributes do

        include AttributeActions

        def bottom_left_node
          if leaf?
            self
          else
            self.children.first.bottom_left_node
          end
        end

        #Sequentialization of the post-order traversal of the tree
        #@return [Array] names of the nodes visited in traversal
        def post_order_trace(acc=[])
          post_order_traversal{|tree| acc.push tree.value.name}
        end

        #@yield [a] gives tree to the block
        def post_order_traversal(&block)
          unless leaf?
            children.each{|i| i.post_order_traversal(&block)}
          end
          yield self
        end

        def attribute_list
          if self.attributes.nil?
            []
          else
            s_attributes.concat(i_attributes)
          end
        end

        def set_name(name)
          self.name = name
          self
        end

        def get_attribute(attr_name)
          if valid_attribute?(attr_name)
            if s_attributes.include?(attr_name)
              attributes[:s_attr][attr_name]
            else
              attributes[:i_attr][attr_name]
            end
          else
            nil
          end
        end

        def s_attributes
          attribute_type_list(:s_attr)
        end

        def i_attributes
          attribute_type_list(:i_attr)
        end

        def attribute_type_list(attr_type)
          attrs = attributes[attr_type]
          attrs.nil? ? [] : attrs.keys
        end

        def store_attribute(attr_name, attr_value)
          if valid_attribute?(attr_name)
            if s_attributes.include?(attr_name)
              attributes[:s_attr].store(attr_name, attr_value)
            else
              attributes[:i_attr].store(attr_name, attr_value)
            end
          else
            nil
          end
        end

        def build_s_attributes(s_attrs)
          if attributes.nil?
            init_attributes
          end
          s_attrs.each{|i| attributes[:s_attr].store(i, nil)}
          self
        end

        def build_i_attributes(i_attrs)
          if attributes.nil?
            init_attributes
          end
          i_attrs.each{|i| attributes[:i_attr].store(i, nil)}
          self
        end

        def init_attributes(params=nil)
          if params.nil?
            self.attributes = {:s_attr => {}, :i_attr => {}}
          else
            s_attr = params[:s_attr].nil? ? {} : params[:s_attr]
            i_attr = params[:i_attr].nil? ? {} : params[:i_attr]
            self.attributes = {:s_attr => s_attr, :i_attr => i_attr}
          end
          self
        end

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
        AttributeActions.validate self
      end

      TreeSeq = TypedSeq.new_seq(Tree)
    end
  end
end
