require 'pry'
#Mixin to create single type collections with type
#enforcement
module TypedSeq
  
  WrongElementType = Class.new(StandardError)
  WrongInitializationType = Class.new(StandardError)
     
  def enforce_type(type)
    Module.new do
      extend self
      @@type = type
      
      def push(obj)
        if obj.instance_of? @@type
          #puts @@type
          super
        else
          puts @@type
          raise WrongElementType,
                wrong_element_error_message(obj, @@type)
        end
      end

      def initialize(obj=nil)
        if obj.nil?
          super()
        else
          seq = super
          unless self.all_correct_types?(seq)
            raise WrongInitializationType,
                  wrong_initialization_error_message(seq, @@type)
          end
          seq
        end
      end

      def all_correct_types?(seq)
        seq.all? {|i| i.instance_of? @@type}
      end

      def wrong_element_error_message(obj, type)
        "The class #{obj.class} of '#{obj}' is not a" \
        " valid element for the #{self.class}. The object" \
        " must be a #{type}."
      end

      def wrong_initialization_error_message(seq, type)
        "The array #{seq} cannot be used to initialize" \
        " an instance of #{self.class}." \
        " It contains one or more elements which are" \
        " not of the #{type} type."
      end
    end
  end
  
end
