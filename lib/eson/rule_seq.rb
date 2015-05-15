require_relative './rule'
require_relative './typed_seq'

module Eson

  RuleSeq = TypedSeq.new_seq(Eson::Rule)

  class RuleSeq

    WrongElementType = Class.new(StandardError)
    MissingRule = Class.new(StandardError)
    CannotMakeTerminal = Class.new(StandardError)

    module CFGOperations

      def terms
        self.members
      end

      def productions
        self.values.select{|i| i.nonterminal?}
      end

      def nonterminals
        productions.map{|i| i.name}
      end

      def terminals
        self.values.select{|i| i.terminal?}.map{|i| i.name}
      end

      def get_rule(rule_name)
        rule_seq.get_rule(rule_name)
      end

      def copy_rules
        Eson::RuleSeq.new self.values
      end

      def make_top_rule(rule_name)
        self.class.send(:define_method, :top_rule){get_rule(rule_name)}
        self
      end

      def to_s
        rule_list = productions.map{|i| i.to_s}
        "#{self.class.to_s.gsub(/Struct::/, "")}" \
        " has the following terminals:\n" \
        "\n#{terminals.join(", ")}" \
        "\n\nand the following productions:\n" \
        "\n#{rule_list.join("\n")}"
      end

      private

      def rule_seq
        Eson::RuleSeq.new self.values
      end
    end

    def self.new_item_error_message
      "One or more of the given array elements are not" \
      " of the type Eson::Rule"
    end

    def make_terminal_rule(new_rule_name, rxp)
      self.push(Rule.new_terminal_rule(new_rule_name, rxp))
    end

    def convert_to_terminal(rule_name)
      if partial_rule?(rule_name)
        raise CannotMakeTerminal, rule_conversion_error_message(rule_name)
      elsif !include_rule?(rule_name)
        raise MissingRule, missing_rule_error_message(rule_name)
      end
      remove_rules(self.get_rule(rule_name).term_names)
      self.map! do |rule|
        new_rule = if rule_name == rule.name
                     Rule.new_terminal_rule(rule.name, rule.rxp)
                   else
                     rule
                   end
        new_rule
      end
    end

    def remove_rules(rule_names)
      if include_rules?(rule_names)
        initialize(self.reject{|i| rule_names.include?(i.name)})
      else
        nil
      end
    end

    def rule_conversion_error_message(rule_name)
      "The Rule #{rule_name} has partial status thus it" \
      " has an undefined regular expression. This Rule" \
      " cannot be converted to a terminal Rule because" \
      "it can't capture tokens."
    end

    def partial_rule?(rule_name)
      self.get_rule(rule_name).partial_status
    end

    #Create a non-terminal production rule that is a concatenation
    #of terminals and non-terminals
    #@param new_rule_name [Symbol] name of the production rule
    #@param rule_names [Array<Symbol>] sequence of the terms in
    #  the rule given in order
    def make_concatenation_rule(new_rule_name, rule_names)
      partial_status = include_rules?(rule_names) ? false : true
      first_rule_name = rule_names.first
      inherited_partial_status = if include_rule?(first_rule_name)
                                   get_rule(first_rule_name).partial_status
                                 else
                                   true
                                 end
      partial_status = inherited_partial_status || partial_status
      rule = Rule.new(new_rule_name,
                      /undefined/,
                      partial_status,
                      ebnf_concat(rule_names))
      prepare_first_set(rule)
      if partial_status
        self.push rule
      else
        self.push rule.compute_start_rxp(self)
      end
    end

    def ebnf_concat(rule_names)
      term_list = rule_names.map do |i|
        rule_to_term(i)
      end
      EBNF::ConcatenationRule.new(term_list)
    end

    def rule_to_term(rule_name)
      if self.include_rule? rule_name
        rule = get_rule(rule_name)
        if rule.terminal?
          EBNF::Terminal.new(rule_name)
        else
          EBNF::NonTerminal.new(rule_name)
        end
      else
        EBNF::NonTerminal.new(rule_name)
      end
    end

    #@param rule [Eson::Rule]
    #@return [nil]
    def prepare_first_set(rule)
      unless rule.partial_status
        build_first_set(rule)
      end
      if rule.option_rule? || rule.repetition_rule?
        rule.first_set.push :nullable
      end
    end

    #Create a non-terminal production rule that is an alternation
    # of terminals and non-terminals
    #@param new_rule_name [Symbol] name of the production rule
    #@param rule_names [Array<Symbol>] the terms in the rule
    def make_alternation_rule(new_rule_name, rule_names)
      partial_status = include_rules?(rule_names) ? false : true
      inherited_partial_status = rule_names.any? do |i|
        include_rule?(i) ? get_rule(i).partial_status : true
      end
      partial_status = inherited_partial_status || partial_status
      rule = Rule.new(new_rule_name,
                      /undefined/,
                      partial_status,
                      ebnf_alt(rule_names))
      prepare_first_set(rule)
      if partial_status
        self.push rule
      else
        self.push rule.compute_start_rxp(self)
      end
    end

    def ebnf_alt(rule_names)
      term_list = rule_names.map do |i|
        rule_to_term(i)
      end
      EBNF::AlternationRule.new(term_list)
    end

    #Create a non-terminal production rule of either a non-terminal
    #  or terminal
    #@param new_rule_name [Symbol] name of the production rule
    #@param rule_name [Array<Symbol>] the single term in the rule
    def make_repetition_rule(new_rule_name, rule_name)
      partial_status = if include_rule?(rule_name)
                         get_rule(rule_name).partial_status
                       else
                         true
                       end
      rule = Rule.new(new_rule_name,
                      /undefined/,
                      partial_status,
                      ebnf_rep(rule_name))
      prepare_first_set(rule)
      if partial_status
        self.push rule
      else
        self.push rule.compute_start_rxp(self)
      end
    end

    def ebnf_rep(rule_name)
      EBNF::RepetitionRule.new(rule_to_term(rule_name))
    end

    #Create a non-terminal production rule of either a non-terminal
    #  or terminal
    #@param new_rule_name [Symbol] name of the production rule
    #@param rule_name [Array<Symbol>] the single term in the rule
    def make_option_rule(new_rule_name, rule_name)
      partial_status = if include_rule?(rule_name)
                         get_rule(rule_name).partial_status
                       else
                         true
                       end
      rule = Rule.new(new_rule_name,
                      /undefined/,
                      partial_status,
                      ebnf_opt(rule_name))
      prepare_first_set(rule)
      if partial_status
        self.push rule
      else
        self.push rule.compute_start_rxp(self)
      end
    end

    def ebnf_opt(rule_name)
      EBNF::OptionRule.new(rule_to_term(rule_name))
    end

    def missing_items_error_message(rule_names)
      names = rule_names.map{|i| ":".concat(i.to_s)}
      "One or more of the following Eson::Rule.name's" \
      " are not present in the sequence: #{names.join(", ")}."
    end

    def include_rules?(rule_names)
      rule_names.all?{ |i| include_rule? i }
    end

    def include_rule?(rule_name)
      if rule_name.is_a? String
        names.include? rule_name.intern
      elsif rule_name.is_a? Symbol
        names.include? rule_name
      else
        false
      end
    end

    def names
      self.map{|i| i.name}
    end

    def get_rule(rule_name)
      unless include_rule?(rule_name)
        raise MissingRule, missing_rule_error_message(rule_name)
      end
      self.find{|i| i.name == rule_name}
    end

    def missing_rule_error_message(rule_name)
      "The Eson::Rule.name ':#{rule_name}' is not present" \
      " in the sequence."
    end

    #Modifies a context free grammar with the properties of
    #an attribute grammar described by attr_map.
    #@param name [String] class of the Struct representing the grammar
    #@param cfg [Struct] a context free grammar containing terms
    #                    referenced in @attr_maps and @action_maps
    #@param attr_maps [Array<Hash>] array of attr_map describing an
    #                               attribute grammar
    #return [Struct] cfg with attribute grammar translation rules
    #                included
    def self.assign_attribute_grammar(name, cfg, attr_maps)
      attr_maps.each do |i|
        terms = if i[:terms].include? :All
                  cfg.terms
                else
                  i[:terms]
                end
        terms.each do |t|
          cfg.send(t).add_attributes(i)
        end
        unless i[:action_mod].nil?
          cfg.extend(i[:action_mod])
        end
      end
      cfg
    end

    #Output a context free grammar for the rules
    #in the RuleSeq
    #@param grammar_name [String] name of the grammar
    #@return [Struct] a struct of class grammar_name
    #  representing a context free grammar
    def build_cfg(grammar_name, top_rule_name=nil)
      rules = self.clone
      include_nullable_rule(rules)
      grammar_struct = Struct.new grammar_name, *rules.names do
        include CFGOperations
      end
      complete_partial_first_sets(rules)
      compute_follow_sets(rules, top_rule_name)
      grammar = grammar_struct.new *rules
      if top_rule_name.nil?
        grammar
      else
        grammar.make_top_rule(top_rule_name)
      end
    end

    def include_nullable_rule(rules)
      unless rules.include_rule?(:nullable)
        rules.make_terminal_rule(:nullable, //)
      end
    end

    def complete_partial_first_sets(rules)
      rules.each do |rule|
        if rule.partial_status
          build_first_set(rule)
          rule.partial_status = false
        end
      end
      rules
    end

    #Compute and set the first_set for a rule. The first_set is the
    #set of terminal names that can legally  appear at the start of
    #the sequences of symbols derivable from a rule. The first_set
    #of a terminal rule is the rule name.
    #@param rule [Eson::Rule] Given rule
    #@eskimobear.specification
    #
    #Prop : The first set of a concatenation is the first set of the
    #       first terms of the rule which are nullable. If all the terms
    #       are nullable then the first set should include :nullable.
    #     : The first set of an alternation is the first set of all of it's
    #       terms combined.
    #     : The first set of an option or repetition is the first set of
    #       it's single term with :nullable included.
    def build_first_set(rule)
      terms = rule.term_names
      set = if rule.concatenation_rule?
              first_nullable_terms = terms.take_while do |term|
                get_rule(term).nullable?
              end
              if first_nullable_terms.empty?
                get_first_set(get_rule(terms.first))
              else
                first_set = first_nullable_terms.each_with_object([]) do |term, acc|
                  acc.concat(get_first_set(get_rule(term)))
                end
                first_set.delete(:nullable)
                if first_nullable_terms.length < terms.length
                  additional_term = terms[first_nullable_terms.length]
                  additional_first_set = get_first_set(get_rule(additional_term))
                  first_set.concat(additional_first_set)
                elsif first_nullable_terms.length == terms.length
                  first_set.push(:nullable)
                end
                first_set.uniq
              end
            elsif rule.alternation_rule?
              terms.each_with_object([]) do |term, acc|
                first_set = get_first_set(get_rule(term))
                acc.concat(first_set)
              end
            elsif rule.repetition_rule?
              get_first_set(get_rule(terms.first))
            elsif rule.option_rule?
              get_first_set(get_rule(terms.first))
            end
      rule.first_set.concat set
    end

    #Ensure a first_set is completed before returning it. Prevents
    #  complications due to ordering of Rules in the RuleSeq.
    #@param rule [Eson::Rule] Given rule
    #@return [Array<Symbol>] first set
    def get_first_set(rule)
      if rule.partial_status
        build_first_set(rule)
      end
      rule.first_set
    end

    #Compute the follow_set of nonterminal rules. The follow_set is
    #the set of terminals that can appear to the right of a nonterminal
    #in a sentence.
    #@param rules [Eson::RuleSeq] list of possible rules
    #@param top_rule_name [Symbol] name of the top rule in the language
    #  from which @rules derives.
    def compute_follow_sets(rules, top_rule_name=nil)
      unless top_rule_name.nil?
        top_rule = rules.get_rule(top_rule_name)
        add_to_follow_set(top_rule, :eof)
      end
      dependency_graph = build_follow_dep_graph(rules)
      dependency_graph.each do |stage|
        stage.each do |tuple|
          rule = rules.get_rule(tuple[:term])
          tuple[:first_set_deps].each do |r|
            add_to_follow_set(rule, r.first_set-[:nullable])
          end
          tuple[:follow_set_deps].each do |r|
            add_to_follow_set(rule, r.follow_set)
          end
        end
      end
    end

    #Builds a dependency graph for computing :follow_set's. This
    #returns tuples which pairs each term with it's dependencies
    #for follow_set computation. Dependencies are divided into
    #:first_set_deps and :follow_set_deps. The tuples are divided
    #into stages to ensure that follow sets are computed in the
    #correct order. Stage 1 contains rules with no dependencies.
    #Stage 2 contains rules with :first_set_deps only. Stage 3 and
    #upwards contains rules with :follow_set_deps from stages
    #before it only.
    #@return [Array] Array of array of tuples. Each tuple has a :term,
    #  and optional :first_set_deps and :follow_set_deps arrays
    def build_follow_dep_graph(rules)
      dep_graph = rules.map do |rule|
        dependency_rules = rules.select{
          |i| i.nonterminal?&&!i.alternation_rule?
        }.select{
          |i| i.term_names.include? rule.name}
        tuple = {:term => rule.name,
                 :dependencies => dependency_rules,
                 :first_set_deps => [],
                 :follow_set_deps => []}
      end
      dep_graph = dep_graph.partition do |t|
        t[:dependencies].empty?
      end

      #Replace :dependencies with :first_set_deps and :follow_set_deps
      #:first_set_deps are those rules which must have their first_set
      #added to the term's follow_set. :follow_set_deps are those rules
      #which must have their follow_set added to the term's follow_set
      dep_graph.last.each do |t|
        t[:dependencies].each do |dep_rule|
          term_list = dep_rule.term_names
          term_position = term_list.index(t[:term])
          nullable_last = term_list.reverse.take_while do |i|
            rules.get_rule(i).nullable?
          end
          term_is_last = term_position == term_list.size - 1
          if term_is_last || nullable_last.include?(t[:term])
            unless dep_rule.name == t[:term]
              t[:follow_set_deps].push(dep_rule)
            end
          else
            term_after = term_list[term_position + 1]
            t[:first_set_deps].push(rules.get_rule(term_after))
          end
        end
      end

      empty_and_filled_follow_set_stages =
        dep_graph.last.partition{|t| t[:follow_set_deps].empty?}
      dep_graph = dep_graph[0...-1].concat(
        empty_and_filled_follow_set_stages)
      no_stage_deps_and_otherwise =
        split_by_follow_set_dep_order(
          empty_and_filled_follow_set_stages.last)
      dep_graph = dep_graph[0...-1].concat(no_stage_deps_and_otherwise)
    end

    #Split a `stage` of tuples into an array of stages such that members
    #of a stage contain follow_set_deps of terms which appear in
    #previous stages. This ensures that the dependencies are ordered.
    #@param stage [Array<tuple>]
    #@return [Array<<Array<tuple>>]
    def split_by_follow_set_dep_order(stage, acc=[])
      all_terms = stage.flat_map{|t| t[:term]}
      final_stages = stage.partition do |t|
        t[:follow_set_deps].none?{|fs| all_terms.include?(fs.name)}
      end
      last_stage = final_stages.last
      acc = acc[0...-1].concat final_stages
      if last_stage.empty?
        acc
      else
        split_by_follow_set_dep_order(last_stage, acc)
      end
    end

    def add_to_follow_set(rule, term_name)
      if term_name.instance_of? Array
        rule.follow_set.concat(term_name)
      else
        rule.follow_set.push(term_name)
      end
    end
  end
end
