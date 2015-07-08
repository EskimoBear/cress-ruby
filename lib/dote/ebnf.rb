module Dote

  #Operations and data structures for the ebnf field
  #  of the Dote::RuleSeq::Rule
  module EBNF

    module Terms
    end

    Terminal = Struct.new(:rule_name) do
      include Terms
    end

    NonTerminal = Struct.new(:rule_name) do
      include Terms
    end

    module Productions
      def production_type
        self.class.to_s.downcase.match(/([^::]+)\z/).to_s.intern
      end
    end

    AG_TerminalRule = Struct.new(:rule_name) do
      include Productions
    end

    ConcatenationRule = Struct.new(:terms) do
      include Productions
    end

    AlternationRule = Struct.new(:terms) do
      include Productions
    end

    RepetitionRule = Struct.new(:terms) do
      include Productions
    end

    OptionRule = Struct.new(:terms) do
      include Productions
    end

    AG_ProductionRule = Struct.new(:terms) do
      include Productions
    end

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

    #FIXME make polymorphic method instead of switch
    def term_names
      if self.terminal? || self.ag_terminal?
        nil
      else
        self.ebnf.terms.map{|i| i.rule_name}
      end
    end

    def to_s
      if terminal?
        "#{self.name}"
      else
        "#{name} := #{self.ebnf_to_s};"
      end
    end

    def ebnf_to_s
      if alternation_rule?
        terms = ebnf.terms
        join_rule_names(terms, " | ")
      elsif concatenation_rule?
        terms = ebnf.terms
        join_rule_names(terms, ", ")
      elsif repetition_rule?
        "{#{ebnf.terms.first.rule_name}}"
      elsif option_rule?
        "[#{ebnf.terms.first.rule_name}]"
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
