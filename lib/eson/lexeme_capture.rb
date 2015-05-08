require_relative './respondent'

module Eson

  #Operations and data structures for the lexeme field
  #  of Eson::RuleSeq::Rule. Token has a
  #  regexp that matches a fixed lexeme or a set of strings.
  module LexemeCapture

    extend Respondent

    WrongLexemeType = Class.new(StandardError)
    SAttrMissing = Class.new(StandardError)
    
    Token = Struct.new :lexeme, :name, :alternation_names,
                       :line_number, :attributes

    uses :name, :start_rxp, :s_attr, :actions

    def match_token(string)
      lexeme = match(string).to_s.intern
      apply_s_attr_actions(make_token(lexeme))
    end

    def match(string)
      string.match(rxp)
    end

    def rxp
      apply_at_start(self.start_rxp)
    end

    def apply_s_attr_actions(token)
      self.actions.each{|i| self.send(i, token)}
      token
    end
    
    def make_token(lexeme)
      attributes = make_attributes_hash
      if lexeme.instance_of? Symbol
        Token.new(lexeme, self.name, nil, nil, attributes)
      elsif lexeme.instance_of? String
        Token.new(lexeme.intern, self.name, nil, nil, attributes)
      else
        raise WrongLexemeType, lexeme_type_error_message(lexeme)
      end
    end

    def make_attributes_hash
      self.s_attr
        .each_with_object({:s_attr => {}}) do |i, a|
        a[:s_attr].store(i, nil)
      end
    end

    #Set attr_name to attr_value if and only if
    #attr_name is present in the attributes.
    def add_s_attr_item(token, attr_name, attr_value)
      if s_attr_hash(token).include?(attr_name)
        s_attr_hash(token).store(attr_name, attr_value)
        token
      else
        raise SAttrMissing,
              "#{attr_name} is not an s_attribute of #{token.name}"
      end
    end

    def s_attr_hash(token)
      token.attributes[:s_attr]
    end
    
    def lexeme_type_error_message(lexeme)
      "Lexeme provided to method #{caller_locations[0].label}" \
      "must be either a Symbol or a String but the given lexeme" \
      "- #{lexeme} is a #{lexeme.class}."
    end

    def match_rxp?(string)
      regex_match?(rxp, string)
    end

    def match_start(string)
      if self.nonterminal?
        string.match(self.start_rxp)
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
