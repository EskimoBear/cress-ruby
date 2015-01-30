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
            build_exception_message(error_token, token_sequence) unless error_token.nil?
      return token_sequence
    end

    private

    def build_exception_message(token, token_seq)
      "'#{token.lexeme}' is not a known special form in line #{token.line_number}:\n #{token.line_number}. #{token_seq.get_program_line(token.line_number)}" 
    end
  end
end
