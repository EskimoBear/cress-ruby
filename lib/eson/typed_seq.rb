module TypedSeq
  
  WrongElementType = Class.new(StandardError)
  WrongInitializationType = Class.new(StandardError)

  #Create anonymous module to prepend to Array subclasses.
  #Enforces single type arrays with type enforcement
  #for #new and #push methods
  #@param type [Constant] type of Array subclass
  #@return [Module] module to prepend for type enforcement
  def enforce_type(type)

    dynamic_methods = proc do |dyn_type|

      define_method :get_type do
        dyn_type
      end

      def push(obj)
        if obj.instance_of? get_type
          super
        else
          raise WrongElementType,
                wrong_element_error_message(obj, get_type)
        end
      end

      def wrong_element_error_message(obj, type)
        "The class #{obj.class} of '#{obj}' is not a" \
        " valid element for the #{self.class}. The object" \
        " must be a #{type}."
      end

      def initialize(obj=nil)
        if obj.nil?
          super()
        else
          seq = super
          unless self.all_correct_types?(seq)
            raise WrongInitializationType,
                  wrong_initialization_error_message(seq, get_type)
          end
          seq
        end
      end

      def all_correct_types?(seq)
        seq.all? {|i| i.instance_of? get_type}
      end

      def wrong_initialization_error_message(seq, type)
        "The array #{seq} cannot be used to initialize" \
        " an instance of #{self.class}." \
        " It contains one or more elements which are" \
        " not of the #{type} type."
      end
    end

    prepend_module = Module.new
    prepend_module.module_exec(type, &dynamic_methods)
    prepend_module
  end
end
