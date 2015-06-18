require_relative './lexeme_capture.rb'
require_relative './ebnf.rb'
require_relative './parser'

module Dote

  #EBNF production rule representation for terminals and non-terminals
  class Rule

    include EBNF
    include LexemeCapture
    include Parser
    
    NoMatchingFirstSet = Class.new(StandardError)
    FirstSetNotDisjoint = Class.new(StandardError)

    attr_accessor :name, :first_set, :partial_status, :ebnf,
                  :follow_set, :start_rxp, :s_attr, :i_attr,
                  :comp_rules

    #@param name [Symbol] name of the production rule
    #@param sequence [Array<Terminal, NonTerminal>] list of terms this
    #  rule references, this list is empty when the rule is a terminal
    #@param start_rxp [Regexp] regexp that accepts valid symbols for this
    #  rule
    #@param partial_status [Boolean] true if any terms are not defined as a
    #  rule or descend from terms with partial_status in their associated
    #  rule.
    #  If a rule has a partial_status then it's full first_set is only
    #  computed when a formal language is derived from said rule.
    #@param ebnf [Dote::EBNF] ebnf definition of the rule, each defintion
    #  contains only one control, thus a rule can be one of the four control
    #  types:- concatenation, alternation, repetition and option.
    def initialize(name, start_rxp=nil, partial_status=nil, ebnf=nil)
      @name = name
      @ebnf = ebnf
      @start_rxp = start_rxp
      @first_set = terminal? ? [name] : []
      @partial_status = terminal? ? false : partial_status
      @follow_set = []
      @s_attr = []
      @i_attr = terminal? ? nil : []
    end

    def to_tree
      if terminal?
        nil
      elsif ag_terminal?
        Parser::ParseTree::Tree.new(@name)
          .make_leaf_node
          .init_attributes(build_leaf_attributes)
      else
        Parser::ParseTree::Tree.new(@name)
          .make_tree_node
          .init_attributes(build_tree_attributes)
      end
    end

    def build_leaf_attributes
      {:s_attr => build_attributes(@s_attr)
                 .merge(production_type_attribute)}
    end

    def build_tree_attributes
      {:s_attr => build_attributes(@s_attr).merge(production_type_attribute),
       :i_attr => build_attributes(@i_attr)}
    end

    def production_type_attribute
      type = if self.concatenation_rule?
               :concatenation
             elsif self.alternation_rule?
               :alternation
             elsif self.repetition_rule?
               :repetition
             elsif self.option_rule?
               :option
             elsif self.ag_production?
               :ag_production
             end
      {:production_type => type}
    end

    def build_attributes(attrs)
      attrs.each_with_object({}){|i, h| h.store(i, nil)}
    end

    def self.new_terminal_rule(name, start_rxp)
      self.new(name, start_rxp)
    end

    #Compute the start rxp of nonterminal rules
    #@param rules [Dote::RuleSeq] the other rules making
    #  up the grammar
    #@return [Dote::RuleSeq::Rule] the mutated Rule
    def compute_start_rxp(rules)
      @start_rxp = if alternation_rule?
                     make_alternation_rxp(rules, term_names)
                   elsif concatenation_rule?
                     make_concatenation_rxp(rules, term_names)
                   elsif repetition_rule?
                     make_repetition_rxp(rules, term_names)
                   elsif option_rule?
                     make_option_rxp(rules, term_names)
                   end
      self
    end

    def make_option_rxp(rules, rule_names)
      make_repetition_rxp(rules, rule_names)
    end

    def make_repetition_rxp(rules, rule_names)
      rules.get_rule(rule_names.first).start_rxp
    end

    def make_concatenation_rxp(rules, rule_names)
      rxp_strings = get_rxp_sources(rules, rule_names)
      combination = rxp_strings.reduce("") do |memo, i|
        memo.concat(i)
      end
      Regexp.new(combination)
    end

    def make_alternation_rxp(rules, rule_names)
      rxp_strings = get_rxp_sources(rules, rule_names)
      initial = rxp_strings.first
      rest = rxp_strings.drop(1)
      combination = rest.reduce(initial) do |memo, i|
        memo.concat("|").concat(i)
      end
      combination.prepend("(").concat(")")
      Regexp.new(combination)
    end

    def get_rxp_sources(rules, rule_array)
      rule_array.map do |i|
        rules.get_rule(i).start_rxp.source
      end
    end

    Parser.validate self
  end
end
