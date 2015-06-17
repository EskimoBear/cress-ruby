module Eson

  #Operations and data structures for the ebnf field
  #  of the Eson::RuleSeq::Rule
  module EBNF

    Terminal = Struct.new(:rule_name)
    NonTerminal = Struct.new(:rule_name)

    ConcatenationRule = Struct.new(:term_list)
    AlternationRule = Struct.new(:term_set)
    RepetitionRule = Struct.new(:term)
    OptionRule = Struct.new(:term)
    AG_TerminalRule = Struct.new(:name)
    AG_ProductionRule = Struct.new(:name)

    def terminal?
      self.ebnf.nil?
    end

    def ag_terminal?
      self.ebnf.instance_of? AG_TerminalRule
    end

    def ag_production?
      self.ebnf.instance_of? AG_ProductionRule
    end

    def nonterminal?
      !terminal? && !ag_production? && !ag_terminal?
    end

    def nullable?
      if self.option_rule? || self.repetition_rule?
        true
      elsif @first_set.include? :nullable
        true
      else
        false
      end
    end

    def alternation_rule?
      self.ebnf.instance_of? AlternationRule
    end

    def concatenation_rule?
      self.ebnf.instance_of? ConcatenationRule
    end

    def repetition_rule?
      self.ebnf.instance_of? RepetitionRule
    end

    def option_rule?
      self.ebnf.instance_of? OptionRule
    end

    def term_names
      if self.terminal? || self.ag_production? || self.ag_terminal?
        nil
      elsif alternation_rule?
        self.ebnf.term_set.map{|i| i.rule_name}
      elsif concatenation_rule?
        self.ebnf.term_list.map{|i| i.rule_name}
      elsif repetition_rule? || option_rule?
        [ebnf.term.rule_name]
      end
    end

    #FIXME this no longer works as terminals which have been
    #converted from nonterminals have an undefined @start_rxp
    def to_s
      if terminal?
        "#{self.name}"
      else
        "#{name} := #{self.ebnf_to_s};"
      end
    end

    def ebnf_to_s
      if alternation_rule?
        terms = ebnf.term_set
        join_rule_names(terms, " | ")
      elsif concatenation_rule?
        terms = ebnf.term_list
        join_rule_names(terms, ", ")
      elsif repetition_rule?
        "{#{ebnf.term.rule_name}}"
      elsif option_rule?
        "[#{ebnf.term.rule_name}]"
      end
    end

    def join_rule_names(terms, infix="")
      initial = terms.first.rule_name.to_s
      rest = terms.drop(1)
      rest.each_with_object(initial){
        |i, memo| memo.concat(infix).concat(i.rule_name.to_s)}
    end
  end
end
