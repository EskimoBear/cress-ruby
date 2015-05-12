require_relative './respondent'

module Eson
  module AttributeActions

    extend Respondent

    MissingAttribute = Class.new(StandardError)
    
    uses :name, :attributes, :comp_rules, :attribute_list,
         :get_attribute, :store_attribute
    
    def eval_s_attributes(envs=nil)
      if envs.nil?
        envs = []
      end
      self.comp_rules.each do |cr|
        env = envs.find{|i| i[:attr] == cr[:attr]}
        env_arg = env.nil? ? cr : cr.merge(env)
        self.send(cr[:method], env_arg)
      end
      self
    end
    
    def valid_attribute?(attribute)
      attribute_list.include?(attribute) ? true : false
    end

    def assign_attribute(param)
      attr = param[:attr]
      attr_value = param[:attr_value]
      validate_attribute(attr)
      store_attribute(attr, attr_value)
    end

    def validate_attribute(attribute)
      unless valid_attribute?(attribute)
        raise MissingAttribute,
              "#{attribute} is not an attribute of #{self.name}"
      end
    end
  end
end
