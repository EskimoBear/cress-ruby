module Dote
  module TypeSystem

    class BooleanType
      def initialize(lexeme)
        @value = if lexeme == :true
                   true
                 elsif lexeme == :false
                   false
                end
      end

      def to_val
        @value
      end
    end

    class NumberType
      def initialize(lexeme)
        @value = lexeme.to_s.to_f
      end

      def to_val
        @value
      end
    end

    class StringType
      def initialize(root_val)
        @value = root_val
      end

      def to_val
        @value
      end
    end

    class VarType
      def initialize(lexeme)
        @variable_identifier_name = StoreReferenceType.new(lexeme)
      end
    end

    class ProcedureType
    end

    class StoreReferenceType
      def initialize(var_name)
      end
    end

    class UnboundType
    end
  end
end
