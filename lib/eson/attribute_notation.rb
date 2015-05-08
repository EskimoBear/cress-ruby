require_relative 'respondent'
require 'vert'

module AttributeNotation

  extend Respondent

  uses :s_attr, :i_attr, :actions

  def add_attributes(attr_map)
    self.add_attribute_lists(attr_map)
    self.add_actions(attr_map)
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

  def add_actions(attr_map)
    unless attr_map[:actions].nil?
      self.actions.concat(attr_map[:actions])
      self.extend(attr_map[:action_mod])
    end
  end
end
