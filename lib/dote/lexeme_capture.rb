require_relative './respondent'
require_relative './attribute_actions'
require_relative './parser.rb'

module Dote

  #Operations and data structures for the lexeme field
  #  of Dote::RuleSeq::Rule. Token has a
  #  regexp that matches a fixed lexeme or a set of strings.
  module LexemeCapture

    extend Respondent
    
    WrongLexemeType = Class.new(StandardError)

    Token = Struct.new :lexeme, :name, :attributes, :comp_rules do

      include AttributeActions

      def to_tree
        Parser::ParseTree::Tree.new(self.name)
          .make_leaf_node
          .init_attributes(build_tree_attributes)
      end

      def build_tree_attributes
        if self.attributes.nil?
          {:s_attr => {}}
        else
          {:s_attr => self.attributes.merge({:lexeme => self.lexeme})}
        end
      end

      def attribute_list
        self.attributes.nil? ? [] : self.attributes.keys
      end

      def build_s_attributes(s_attrs)
        self.attributes =
          s_attrs.each_with_object({}) do |i, a|
          a.store(i, nil)
        end
        self
      end

      def build_actions(comp_rules)
        self.comp_rules = comp_rules
        self
      end

      def get_attribute(attr_name)
        if attribute_list.include?(attr_name)
          self.attributes[attr_name]
        else
          nil
        end
      end

      def store_attribute(attr_name, attr_value)
        self.attributes.store(attr_name, attr_value)
      end
      AttributeActions.validate self
    end

    uses :name, :start_rxp, :s_attr, :actions

    def match_token(string, env=nil)
      lexeme = match(string).to_s.intern
      make_token(lexeme, env)
    end

    def match(string)
      string.match(rxp)
    end

    def rxp
      apply_at_start(self.start_rxp)
    end

    def make_token(lexeme, env=nil)
      lexeme = if lexeme.is_a?(Symbol) || lexeme.is_a?(String)
                 lexeme.intern
               else
                 raise WrongLexemeType,
                       lexeme_type_error_message(lexeme)
               end
      Token.new(lexeme, self.name, nil, nil)
        .build_s_attributes(self.s_attr)
        .assign_envs(env)
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
