module Dote::DoteGrammars

  def var_store
    RuleSeq.assign_attribute_grammar(
      ast,
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
      attribute_names = bind_nodes
                        .map{|i| i.children.first.get_attribute(:lexeme)}
      attribute_names.each do |i|
        store.store(var_name(i), nil)
      end
      store
    end

    def var_name(attribute_name)
      attribute_name.to_s.gsub("\"", "").gsub(/\s/, "_")
        .prepend("V_").intern
    end

    def add_let_params_to_store(tree, store)
      apply_nodes = tree.select{|i| i === :apply}
      let_variables = apply_nodes
                      .select{|i| i.children.first
                               .get_attribute(:lexeme).to_s == "\"&let\""}
                      .flat_map{|i| i.children.last.children}
      let_variables.each do |i|
        if i.name == :literal_string
          store.store(var_name(i.get_attribute(:value)), nil)
        end
      end
      store
    end
  end
end
