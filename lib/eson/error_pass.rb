require_relative 'language.rb'

module Eson
  
  module ErrorPass

    extend self

    LANG = Eson::Language.tokenizer_lang
    SpecialFormError = Class.new(StandardError)
    
    #Throw SpecialFormError when unknown_special_forms Token is present
    #@param token_sequence [Array<Eson::Tokenizer::Token>] A sequence of tokens for E0
    #@return [Array<Eson::Tokenizer::Token>] A sequence of tokens for derivative formal language, E1
    def verify_special_forms(token_sequence)
      error_token = token_sequence.find { |i| i.name == LANG.unknown_special_form.name}
      raise SpecialFormError,
            build_exception_message(error_token.lexeme) unless error_token.nil?
      return token_sequence
    end

    private

    def build_exception_message(lexeme)
      "'#{lexeme}' is not a known special form:\n\t#{locate_line()}"
    end

    def locate_line()
      "TODO print occurence of error"
    end
  end
end
