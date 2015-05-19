require_relative 'respondent'
require 'vert'

module AttributeNotation

  extend Respondent

  uses :s_attr, :i_attr, :actions

  def add_attributes(attr_map)
    self.add_attribute_lists(attr_map)
    unless attr_map[:actions].nil?
      self.add_comp_rules(attr_map)
    end
  end

  def add_comp_rules(attr_map)
    attr_map[:actions].each do |i|
      comp_rule = {:method => i,
                   :attr => attr_map[:attr]}
      self.comp_rules.push comp_rule
    end
  end

  def add_attribute_lists(attr_map)
    attribute = attr_map[:attr]
    attr_type = attr_map[:type]
    if attr_type == :s_attr
      self.s_attr.push(attribute)
    elsif attr_type == :i_attr && self.nonterminal?
      self.i_attr.push(attribute)
    end
  end
end
