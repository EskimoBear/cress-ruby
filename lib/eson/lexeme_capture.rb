module Eson

  #Operations and data structures for the lexeme field
  #  of Eson::RuleSeq::Rule. Token has a
  #  regexp that matches a fixed lexeme or a set of strings.
  module LexemeCapture

    WrongLexemeType = Class.new(StandardError)

    Token = Struct.new :lexeme, :name, :alternation_names, :line_number

    def make_token(lexeme)
      if lexeme.instance_of? Symbol
        Token.new(lexeme, @name)
      elsif lexeme.instance_of? String
        Token.new(lexeme.intern, @name)
      else
        raise WrongLexemeType, lexeme_type_error_message(lexeme)
      end
    end

    def lexeme_type_error_message(lexeme)
      "Lexeme provided to method #{caller_locations[0].label}" \
      "must be either a Symbol or a String but the given lexeme" \
      "- #{lexeme} is a #{lexeme.class}."
    end

    def match_token(string)
      lexeme = self.match(string).to_s.intern
      self.make_token(lexeme)
    end

    def match(string)
      string.match(rxp)
    end

    def rxp
      apply_at_start(@start_rxp)
    end

    def match_rxp?(string)
      regex_match?(self.rxp, string)
    end

    def match_start(string)
      if self.nonterminal?
        string.match(@start_rxp)
      else
        nil
      end
    end

    def regex_match?(regex, string)
      #does not catch zero or more matches that return "", the empty stri\
      ng
      (string =~ apply_at_start(regex)).nil? ? false : true
    end

    def apply_at_start(regex)
      /\A#{regex.source}/
    end
  end
end
