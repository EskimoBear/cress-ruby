# Allows Mixins to document their method dependencies with the
# `uses` method. Receiver classes/modules can check that they
# support these dependencies by calling the `validate` class
# method. The `validate` method is automatically generated and
# should follow the definition of the dependency.
# @example
#    module Enumerable
#      uses :each
#    end
#
#    class GoodArray
#      extend Enumerable
#      Enumerable.validate(self)
#    end
module Respondent

  extend self

  # A method supplied to {Respondent#uses} is not defined
  # in the receiver class/module.
  MissingMethod = Class.new(StandardError)

  # Gives calling module access to .validate method
  # which is dynamically created with the methods array.
  # The .validate method checks if all required methods are
  # provided by the receiver of the Module that calls .uses.
  # @param methods [Array<Symbols>] names of required methods
  #  for `validate`.
  # @example
  #    module Enumerable
  #      uses :each
  #    end
  def uses(*methods)
    self.extend validator_module(methods)
  end

  # @param method_names [Array<symbols>] names of methods
  #   tested by {Respondent#validate}.
  # @return [Module] anonymous module containing `validate` method.
  def validator_module(method_names)
    module_body = proc do |methods|

      extend self
      
      define_method :get_methods do
        methods
      end

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

  # @!method validate(receiver)
  # Checks that all required methods are provided by
  # the receiver. This method is dynamically generated
  # by {Respondent#validator_module} with the required
  # methods as its arguments.
  # @see Respondent#validator_module
  # @see Respondent#uses
  # @param receiver [Module] module/class to be validated
  # @raise [MissingMethod]

end


