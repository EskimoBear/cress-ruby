module VariableStore

  def build_store(tree)
    create_variables(tree, {})
  end

  def create_variables(tree, store={})
    add_attributes_to_store(tree, store)
    add_let_params_to_store(tree, store)
  end

  def add_attributes_to_store(tree, store)
    attribute_nodes = tree.find_all{|i| i.name == :attribute}
    attribute_names = tree.find_all{|i| i.name == :attribute_name}
                      .map{|t| t.get_attribute(:lexeme)}
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
    let_variables = tree.find_all{|i| i.name == :call}
        .select{|i| i.children.first.contains?(:special_form_identifier)}
        .select{|i| i.children.first.find{|t| t.get_attribute(:lexeme).to_s == "\"&let\""}}.first
        .find_all{|i| i.name == :sub_string}
        .map{|i| i.children[0].get_attribute(:lexeme)}
    let_variables.each{|i| store.store(var_name(i), nil)}
    store
  end
end
