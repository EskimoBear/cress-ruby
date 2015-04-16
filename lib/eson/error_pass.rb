module Eson
  module ErrorPass

    LANG = Eson::EsonGrammars.tokenizer_lang
    
    UnknownSpecialForm = Class.new(StandardError)

    #Detect unknown_special_forms Token in self
    #@return [TokenSeq] self when Token is not found
    #@raise [UnknownSpecialForm] unknown_special_forms Token found
    def verify_special_forms
      error_token = self.find do |i|
        i.name == LANG.unknown_special_form.name
      end
      unless error_token.nil?
        raise UnknownSpecialForm,
	      unknown_special_form_error_message(error_token)
      end
      return self
    end

    private

    def unknown_special_form_error_message(token)
      line_num = token.line_number
      "'#{token.lexeme}' is not a known special_form in" \
      " line #{line_num}:\n #{line_num}." \
      " #{get_program_snippet(line_num)}"
    end
    
    def get_program_snippet(line_num)
      "\n #{line_num}." \
      " #{self.get_program_line(line_num)}"
    end
  end
end
