module Respondent

  extend self
  
  MissingMethod = Class.new(StandardError)

  #Gives calling module access to .validate method
  #which is dynamically created with the methods array.
  #The .validate method checks if all required methods are
  #provided by the receiver of the Module that calls .uses.
  #@param methods [Array<Symbols>] names of required methods
  # for validate
  def uses(*methods)
    self.extend validate_module(methods)
  end

  def validate_module(method_names)
    module_body = proc do |methods|

      extend self
      
      define_method :get_methods do
        methods
      end

      #Checks that all required methods are provided by
      #receiver.
      #see @uses
      #@param receiver [Module] module/class to be validated
      #@raise [MissingMethod] if a method supplied to .uses
      #  is not defined in the receiver
      def validate(receiver)
        get_methods.each do |i|
          unless receiver.instance_methods.include?(i)
            raise MissingMethod,
                  methods_missing_error_message(i, receiver)
          end
        end
      end

      def methods_missing_error_message(method_name, receiver_name)
        "The :#{method_name} method was not found" \
        " in #{receiver_name}. The methods #{get_methods.to_s[1...-1]}"\
        " are required for the correct operation of #{self}."
      end
    end

    mod = Module.new
    mod.module_exec(method_names, &module_body)
    mod
  end
end


