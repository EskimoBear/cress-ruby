require_relative 'respondent'
require 'vert'

module AttributeNotation

  extend Respondent

  uses :s_attr, :i_attr, :actions
  
  def add_attribute(attr_map)
    attribute = attr_map[:attr]
    attr_type = attr_map[:type]
    if attr_type == :s_attr
      self.s_attr.push(attribute)
    elsif attr_type == :i_attr && self.nonterminal?
      self.i_attr.push(attribute)
    end
  end

  def add_action(action_map)
    self.actions.concat(action_map[:actions])
    self.extend(action_map[:action_mod])
  end
end
