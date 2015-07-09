module Dote::DoteGrammars

  def var_store_cfg
    RuleSeq.new(ast.copy_rules)
      .concat(Dote::DoteGrammars.make_reserved_keys_rules([:let, :ref, :doc]))
      .build_cfg(:program)
  end

  def var_store
    RuleSeq.assign_attribute_grammar(
      var_store_cfg,
      [AST, VariableStore],
      [])
  end

  module VariableStore

    include ISemantics

    def build_store(tree)
      create_variables(tree, {})
    end

    def create_variables(tree, store={})
      add_attributes_to_store(tree, store)
      add_let_params_to_store(tree, store)
    end

    def add_attributes_to_store(tree, store)
      bind_nodes = tree.find_all{|i| i === :bind}
      bind_nodes.each do |bn|
        attribute_name_node = bn.children.first
        variable_name = var_name(attribute_name_node.get_attribute(:lexeme))
        value_node = bn.children.last
        value = value_node.get_attribute(:lexeme)
        store.store(variable_name, nil)
      end
      store
    end

    def var_name(attribute_name)
      attribute_name.to_s.gsub("\"", "").gsub(/\s/, "_")
        .prepend("V_").intern
    end

    def add_let_params_to_store(tree, store)
      select_built_in_procs(tree, :let).each do |ln|
        ln.children.last.children.each do |param|
          if param.name == :literal_string
            store.store(var_name(param.get_attribute(:value)), nil)
          end
        end
      end
      store
    end

    # Find all built in procedures in the AST matching
    # reserved_key_name.
    # @param tree [Parser::ParseTree]
    # @param reserved_key_name [Symbol]
    # @return [Array<Parser::ParseTree::Tree>]
    def select_built_in_procs(tree, reserved_key_name)
      reserved_key_rule = self.get_rule(reserved_key_name)
      apply_nodes = tree.select{|i| i === :apply}
      reserved_key_nodes = apply_nodes.select do |an|
        proc_identifiers = an.children.first
        reserved_key_rule.match(proc_identifiers.get_attribute(:lexeme).to_s)
      end
    end
  end
end
