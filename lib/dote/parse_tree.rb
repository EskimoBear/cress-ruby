require 'forwardable'
require_relative '../../utils/typed_seq'
require_relative './attribute_actions'
require_relative './parse_tree_transformations'

module Parser

  class ParseTree
    CannotConvertTypeToTree = Class.new(StandardError)
    UnallowedMethodForClosedTree = Class.new(StandardError)

    include Enumerable
    include TreeTransformations
    extend Forwardable

    attr_reader :height

    # Initialize tree with obj as root node. An empty
    # tree is created if no parameter is given.
    # @param obj [Dote::Rule] Rule
    def initialize(obj=nil)
      init_empty
      set_root(obj)
    end

    def init_empty
      @height = 0
      @root_tree = @active = Tree.new
    end

    # Make the obj the root node of the ParseTree. If children is
    # given, initialize as the child list of the root node.
    # @param obj [#to_tree] root node
    # @param children [TreeSeq] child list of root node
    def set_root(obj, children=nil)
      unless obj.nil?
        @root_tree = @active = convert_to_tree(obj)
        @height = 1
        if children
          @root_tree.adopt_child_list(children)
          update_height
        end
        if @active.leaf?
          close_active
        end
      end
    end

    # @return [Array<Tree>] all nodes excluding the root
    def descendants
      @root_tree.entries.drop(1)
    end

    #@param obj [#to_tree] the object to be converted to a tree node
    #@return [Parser::ParseTree::Tree] the resulting tree
    #@raise [CannotConvertTypeToTree] if the object cannot return
    #  a tree with #to_tree
    def convert_to_tree(obj)
      tree = if obj.instance_of? Parser::ParseTree::Tree
               obj
             else
               tree = obj.to_tree
             end
      if tree.instance_of? Tree
        tree.parent = active_node
        tree.set_level
      else
        raise CannotConvertTypeToTree,
              invalid_input_type_error_message(obj)
      end
    rescue NoMethodError => e
      raise CannotConvertTypeToTree,
            invalid_input_type_error_message(obj)
    end

    #Insert an object into the active tree node. If the object is
    # a tree node it becomes the new active node.
    #@param obj [#to_tree] object to be added as a Tree node
    #@raise [UnallowedMethodForClosedTree] If the tree is closed
    def insert(obj)
      if empty_tree?
        set_root(obj)
      else
        ensure_open
        new_tree = convert_to_tree(obj)
        active_node.children.push new_tree
        update_height(new_tree)
        unless new_tree.leaf?
          @active = new_tree
        end
      end
      self
    end

    def update_height(tree=nil)
      if tree.nil?
        @height = self.max_by{|t| t.level}.level
      elsif tree.level > @height
        @height = tree.level
      end
    end

    def invalid_input_type_error_message(obj)
      "The class #{obj.class} of '#{obj}' is not a" \
      " valid input for the #{self.class}. Input" \
      " must be return a #{Parser::ParseTree} for :to_tree."
    end

    #Add a given tree to this tree's active node
    #@param tree [Parser::ParseTree]
    #@raise [MergeError] if tree is not closed before merging
    def merge(tree)
      if tree.closed?
        tree.get.increment_levels(active_node.level)
        possible_height = tree.height + active_node.level
        @height = @height < possible_height ? possible_height : @height
        tree.get.parent = @active
        @active.children.push(tree.get)
        self
      end
    end

    #Get the active node of the tree. This is the open tree node to
    #the bottom right of the tree i.e. the last inserted tree node.
    #@return [Parser::ParseTree::Tree] the active tree node
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
    #@return [Parser::ParseTree]
    def close_active
      new_active = @active.parent
      @active.close
      unless new_active.empty_tree?
        @active = new_active
      end
      self
    end

    def_delegators :@root_tree, :each, :degree, :closed?,
                   :open?, :leaf?, :ensure_open, :has_child?,
                   :has_children?, :rule, :children, :level,
                   :empty_tree?, :contains?, :attribute_list,
                   :get_attribute, :store_attribute, :bottom_left_node,
                   :post_order_trace, :post_order_traversal,
                   :attributes, :name, :===

    #Struct class for a tree node
    Tree = Struct.new :name, :open_state, :attributes,
                      :children, :parent, :level do

      include Enumerable
      include Dote::AttributeActions

      # Add a list of child nodes to this node's children
      # @param children [TreeSeq] list of child nodes
      # @return [nil]
      def adopt_child_list(children)
        self.children.concat children
        children.each{|cn| cn.parent = self}
      end

      # (see TreeTransformations#delete_root)
      def delete_node(tree_match)
        if leaf?
          leaf_index = parent.children
                       .index{|cn| cn === tree_match}
          parent.children.delete_at(leaf_index)
        else
          remove_root(tree_match)
        end
      end

      def reduce_root
        if degree == 1
          new_root = children.first
          new_root.parent = parent
          new_root.increment_levels(0)
          self.replace(new_root)
        end
      end

      #@param (see ParseTree#remove_root)
      def remove_root(tree_match)
        if !parent.empty_tree? && internal?
          children.each{|cn| cn.parent = self.parent}
          root_index = parent.children.index{|cn| cn === tree_match}
          parent.children.replace insert_child_at_index(
                                    root_index,
                                    parent.children,
                                    self.children)
          parent.increment_levels
          parent
        end
      end

      def insert_child_at_index(index, child_list, new_child_list)
        original_size = child_list.length
        child_list.concat new_child_list
        start_list = child_list.take(index)
        middle_list = child_list.drop(original_size)
        end_list = child_list[(index + 1)...original_size]
        child_list.delete_at(index)
        start_list + middle_list + end_list
      end

      def replace(new_tree)
        self.name = new_tree.name
        self.open_state = new_tree.open_state
        self.attributes = new_tree.attributes
        self.parent = new_tree.parent
        self.children = new_tree.children
        self.level = new_tree.level
        self
      end

      def ===(param)
        if name == param
          true
        elsif get_attribute(:production_type)
          if get_attribute(:production_type) == param
            true
          end
        else
          false
        end
      end

      def make_tree_node
        self.children = TreeSeq.new
        self.open_state = true
        self
      end

      def make_leaf_node
        self.children = nil
        self.open_state = false
        self
      end

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
        post_order_traversal{|tree| acc.push tree.name}
      end

      #pre-order traversal of the tree
      #@yield [a] gives tree to the block
      def each(&block)
        if leaf?
          yield self
        else
          yield self
          children.each{|i| i.each(&block)}
        end
      end

      #post-order traversal of the tree
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

      def close
        self.open_state = false
      end

      #@return [Boolean] true if Tree is open
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
        children.nil?
      end

      def internal?
        !leaf?
      end

      def empty_tree?
        name.nil?
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

      #@param tree_match [Symbol] case match of a child node
      def has_child?(tree_match)
        children.detect{|i| i === tree_match} ? true : false
      end

      #@param tree_matchers [Array<Symbol>] ordered list of case
      # matchers for child nodes
      def has_children?(names)
        children.zip(names).map{|i| i.first === i.last}.all?
      end

      #@param (see #has_child?)
      #@return [Boolean] true if a matching Tree is present
      def contains?(tree_match)
        !find{|i| i === tree_match}.nil?
      end

      #@param offset [Integer]
      def set_level(offset=0)
        self.level = parent.empty_tree? ? 1 : 1 + parent.level
        self.level = level + offset
        self
      end

      #Increment the tree levels of a given tree
      #@param offset [Integer]
      def increment_levels(offset=0)
        set_level(offset)
        unless leaf?
          children.each{|t| t.set_level}
        end
      end

      Dote::AttributeActions.validate self
    end

    TreeSeq = TypedSeq.new_seq(Tree)
    TreeTransformations.validate self
  end
end
