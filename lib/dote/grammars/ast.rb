module Dote::DoteGrammars

  def ast_cfg
    RuleSeq.new(display_fmt.copy_rules)
      .make_ag_production_rule(:bind, [:attribute_name, :value])
      .make_ag_production_rule(:apply, [:proc_identifier, :value])
      .make_ag_terminal_rule(:literal_string, [:value])
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
      make_literal_strings(tree)
    end

    def make_operators_root(tree)
      attributes = tree.select{|i| i === :attribute}
      attributes.each{|i| transform_to(:bind, i)}
      calls = tree.select{|i| i === :call}
      calls.each{|i| transform_to(:apply, i)}
      tree
    end

    def make_literal_strings(tree)
      strings = tree.select{|i| i === :string}
      strings.each do |i|
        make_empty_literal_string(i)
        make_filled_literal_string(i)
        make_interpolated_string(i)
      end
    end

    def make_empty_literal_string(node)
      if (node.degree == 1) && (node.children.first === :nullable)
        nullable = node.children.first
        nullable.replace get_rule(:literal_string).to_tree
        nullable.store_attribute(:value, "")
        node.reduce_root
      end
    end

    def make_filled_literal_string(node)
      if node.degree >= 1
        if node.children.all?{|i| i === :word_form}
          string = node.children.reduce("") do |acc, i|
            acc.concat(i.get_attribute(:lexeme).to_s)
          end
          node.replace get_rule(:literal_string).to_tree
          node.store_attribute(:value, string)
        end
      end
    end

    def make_interpolated_string(node)
      if node.degree >= 1
        if node.children.any?{|i| i === :variable_identifier}
          node.replace get_rule(:interpolated_string).to_tree
        end
      end
    end
  end
end
