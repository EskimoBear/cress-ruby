require_relative 'language.rb'

module Eson
  
  module CompilePass

    extend self

    SpecialFormError = Class.new(StandardError)
    
    #Throw SpecialFormError when unknown_special_forms Token is present
    #
    #@param token_sequence [Array<Eson::Tokenizer::Token>] A sequence of tokens for E0
    #@param input_lang [E0] The formal language describing token_sequence
    #@return [Array<Eson::Tokenizer::Token>] A sequence of tokens for E1
    #@return [E1] Derivative formal language
    def verify_special_forms(token_sequence, input_lang)
      error_token = token_sequence.find { |i| i.type == input_lang.unknown_special_form.name}
      raise SpecialFormError,
            build_exception_message(error_token.lexeme) unless error_token.nil?
      return token_sequence, Eson::Language.verified_special_forms_lang
    end

    def build_exception_message(lexeme)
      "'#{lexeme}' is not a known special form:\n\t#{locate_line()}"
    end

    def locate_line()
      "TODO print occurence of error"
    end
  end
end
