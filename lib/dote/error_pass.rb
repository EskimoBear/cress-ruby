require_relative './program_errors'

module Dote
  module ErrorPass

    include ProgramErrors

    LANG = Dote::DoteGrammars.compile_grammar
    
    #@return [TokenSeq] self when Token is not found
    #@raise [UnknownSpecialForm] unknown_special_forms Token found
    def verify_special_forms
      error_token = self.find do |i|
        i.name == LANG.get_rule(:unreserved_procedure_identifier).name
      end
      unless error_token.nil?
        raise UnknownSpecialForm,
	      unknown_special_form_error_message(error_token, self)
      end
      return self
    end
  end
end
