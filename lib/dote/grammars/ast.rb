module Dote::DoteGrammars

  def ast_cfg
    RuleSeq.new(display_fmt.copy_rules)
      .make_ag_production_rule(:bind, [:attribute_name, :value])
      .make_ag_production_rule(:apply, [:proc_identifier, :value])
      .make_ag_terminal_rule(:literal_string)
      .make_ag_production_rule(:interpolated_string, [])
      .build_cfg(:program)
  end

  def ast
    RuleSeq.assign_attribute_grammar(
      ast_cfg,
      [AST, DisplayFormat],
      [])
  end

  module AST

    include ISemantics

    def eval_tree_attributes(tree)
      tree
    end

    def convert_to_ast(tree)
      remove_alternation_rules(tree)
      remove_option_rules(tree)
      remove_repetition_rules(tree)
      reduce_array_set(tree)
      reduce_program_set(tree)
      reduce_string(tree)
      make_operators_root(tree)
    end

    def remove_alternation_rules(tree)
      tree.reduce_roots(:alternation)
    end

    def remove_option_rules(tree)
      tree.reduce_roots(:option)
    end

    def remove_repetition_rules(tree)
      tree.remove_roots(:repetition)
    end

    def reduce_array_set(tree)
      tree.remove_roots(:element_list)
      tree.remove_roots(:element_more)
      tree.remove_roots(:element_more_once)
      tree.delete_nodes(:element_divider)
      tree.delete_nodes(:array_start)
      tree.delete_nodes(:array_end)
      remove_nullable_child(tree, :array)
    end

    def remove_nullable_child(tree, tree_match)
      tree.find_all{|i| i === tree_match}
        .select{|i| i.has_child? :nullable}
        .select{|i| i.degree > 1}
        .map{|i| i.children}
        .each do |cl|
        cl.each {|t| t === :nullable ? t.delete_node(:nullable) : nil}
      end
      tree
    end

    def reduce_program_set(tree)
      tree.delete_nodes(:declaration_list)
      tree.delete_nodes(:declaration_more_once)
      tree.delete_nodes(:declaration_divider)
      tree.delete_nodes(:program_start)
      tree.delete_nodes(:program_end)
      remove_nullable_child(tree, :program)
    end

    def reduce_string(tree)
      tree.delete_nodes(:string_delimiter)
      remove_nullable_child(tree, :string)
      make_string_nodes(tree)
    end

    def make_operators_root(tree)
      attributes = tree.select{|i| i === :attribute}
      attributes.each{|i| transform_to(:bind, i)}
      calls = tree.select{|i| i === :call}
      calls.each{|i| transform_to(:apply, i)}
      tree
    end

    def make_string_nodes(tree)
      strings = tree.select{|i| i === :string}
      strings.each do |i|
        make_literal_string_node(i)
        make_interpolated_string(i)
      end
    end

    def make_literal_string_node(string_node)
      if string_node.children.none?{|i| i === :variable_identifier}
        assign_nullable_empty_string(string_node)
        convert_to_literal_string_node(string_node)
      end
    end

    def assign_nullable_empty_string(string_node)
      first_child = string_node.children.first
      if first_child === :nullable
        first_child.store_attribute(:val, "")
      end
    end

    def convert_to_literal_string_node(string_node)
      root_string = build_root_string(string_node)
      string_node.replace get_rule(:literal_string).to_tree
      string_node.store_attribute(:val, root_string)
    end

    def build_root_string(string_node)
      root_string = string_node.children.reduce("") do |acc, i|
        acc.concat(i.get_attribute(:lexeme).to_s)
      end
    end

    def make_interpolated_string(string_node)
      unless string_node === :literal_string
        if string_node.children.any?{|i| i === :variable_identifier}
          string_node.replace_root get_rule(:interpolated_string)
        end
      end
    end

  end
end
