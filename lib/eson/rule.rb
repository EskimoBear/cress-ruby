require_relative './lexeme_capture.rb'
require_relative './ebnf.rb'
require_relative './abstract_syntax_tree.rb'
require_relative './attribute_notation.rb'

module Eson

  #EBNF production rule representation for terminals and non-terminals
  class Rule

    include EBNF
    include LexemeCapture
    include AttributeNotation
    
    InvalidSequenceParsed = Class.new(StandardError)
    NoMatchingFirstSet = Class.new(StandardError)
    FirstSetNotDisjoint = Class.new(StandardError)

    attr_accessor :name, :first_set, :partial_status, :ebnf,
                  :follow_set, :start_rxp, :s_attr, :i_attr,
                  :actions

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
    #@param ebnf [Eson::EBNF] ebnf definition of the rule, each defintion
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
      @actions = []
    end

    def self.new_terminal_rule(name, start_rxp)
      self.new(name, start_rxp)
    end

    #Return a Token sequence that is a legal instance of
    #  the rule
    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
    #@eskimobear.specification
    # T, input token sequence
    # S, sub-sequence matching rule
    # E, sequence of error tokens
    # r_def, definition of rule
    # et, token at the head of T
    #
    # Init : length(T) > 0
    #        length(S) = 0
    #        length(E) = 0
    # Next : T' = T - et
    #        when r_def.terminal?
    #          when match(r_def.name, et)
    #            S = match(r_def, et)
    #          otherwise
    #            E' = E + et
    #        when r_def.alternation?
    #          when match_any(r_def, T)
    #            S' = match_any(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.concatenation?
    #          when match_and_then(r_def, T)
    #            S' = match_and_then(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.option?
    #          when match_one(r_def, T)
    #            S' = match_one(r_def, T)
    #          otherwise
    #            S' = match_none(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.repetition?
    #          when match_many(r_def, T)
    #            S' = match_many(r_def, T)
    #          otherwise
    #            S' = match_none(r_def, T)
    #          otherwise
    #            E' = E + et
    # Next : T' = T - et
    #        when r_def.terminal?
    #          when match(r_def.name, et)
    #            S = match(r_def, et)
    #          otherwise
    #            E' = E + et
    #        when r_def.alternation?
    #          when match_any(r_def, T)
    #            S' = match_any(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.concatenation?
    #          when match_and_then(r_def, T)
    #            S' = match_and_then(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.option?
    #          when match_one(r_def, T)
    #            S' = match_one(r_def, T)
    #          otherwise
    #            S' = match_none(r_def, T)
    #          otherwise
    #            E' = E + et
    #        when r_def.repetition?
    #          when match_many(r_def, T)
    #            S' = match_many(r_def, T)
    #          otherwise
    #            S' = match_none(r_def, T)
    #          otherwise
    #            E' = E + et
    def parse(tokens, rules, tree=nil)
      if terminal?
        acc = parse_terminal(tokens, tree)
      else
        if tree.nil?
          tree = AbstractSyntaxTree.new
        end
        tree.insert(self)
        acc = if alternation_rule?
                parse_any(tokens, rules, tree)
              elsif concatenation_rule?
                parse_and_then(tokens, rules, tree)
              elsif option_rule?
                parse_maybe(tokens, rules, tree)
              elsif repetition_rule?
                parse_many(tokens, rules, tree)
              end
        acc[:tree].close_active
        acc
      end
    end

    #Return a Token sequence with one Token that is an instance of
    #  a terminal rule
    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be foungg189d
    def parse_terminal(tokens, tree)
      lookahead = tokens.first
      if @name == lookahead.name
        leaf = AbstractSyntaxTree.new(lookahead)
        tree = if tree.nil?
                 leaf
               else
                 tree.merge(leaf)
               end
        build_parse_result([lookahead], tokens.drop(1), tree)
      else
        raise InvalidSequenceParsed,
              parse_terminal_error_message(@name, lookahead, tokens)
      end
    end

    def build_parse_result(parsed_seq, rest, tree)
      if parsed_seq.instance_of? Array
        parsed_seq = Eson::TokenPass::TokenSeq.new(parsed_seq)
      elsif rest.instance_of? Array
        rest = Eson::TokenPass::TokenSeq.new(rest)
      end
      result = {:parsed_seq => parsed_seq, :rest => rest, :tree => tree}
    end

    def parse_terminal_error_message(expected_token,
                                     actual_token,
                                     token_seq)
      line_num = actual_token.line_number
      "Error while parsing #{@name}." \
      " Expected a symbol of type :#{expected_token} but got a" \
      " :#{actual_token.name} instead in line #{line_num}:"
      "\n #{line_num}. #{token_seq.get_program_line(line_num)}\n"
    end

    #Return a Token sequence that is a legal instance of
    #  an alternation rule
    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
    #@eskimobear.specification
    # T, input token sequence
    # et, token at the head of T
    # r_def, list of terms in rule
    # S, sub-sequence matching rule
    # E, sequence of error tokens
    #
    # Init : length(T) > 0
    #        length(E) = 0
    #        length(S) = 0
    # Next : r_term = match_first(r_def, et)
    #        when r_term.terminal?
    #            S' = S + et
    #            T' = T - et
    #        when r_term.nonterminal?
    #          when r_term.can_parse?(r_def, T)
    #            S' = r_term.parse(r_def, T)
    #            T' = T - S'
    #            r_def' = []
    #        otherwise
    #          E + et
    def parse_any(tokens, rules, tree)
      lookahead = tokens.first
      if matched_any_first_sets?(lookahead, rules)
        term = first_set_match(lookahead, rules)
        rule = rules.get_rule(term.rule_name)
        t = rule.parse(tokens, rules, tree)
        return t
      end
      raise InvalidSequenceParsed,
            parse_terminal_error_message(@name, lookahead, tokens)
    end

    #@param token [Eson::LexemeCapture::Token] token
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Boolean] true if token is part of the first set of any
    #  of the rule's terms.
    def matched_any_first_sets?(token, rules)
      terms = get_matching_first_sets(token, rules)
      terms.length.eql?(1)
    end

    def get_matching_first_sets(token, rules)
      @ebnf.term_set.find_all do |i|
        rule = rules.get_rule(i.rule_name)
        rule.first_set.include? token.name
      end
    end

    #@param token [Eson::LexemeCapture::Token] token
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Terminal, NonTerminal] term that has a first_set
    #  which includes the given token. Works with alternation rules only.
    #@raise [FirstSetNotDisjoint] if more than one term found
    #@raise [NoMatchingFirstSet] if no terms found
    def first_set_match(token, rules)
      terms = get_matching_first_sets(token, rules)
      case terms.length
      when 1
        terms.first
      when 0
        raise NoMatchingFirstSet,
              "None of the first_sets of #{@name} contain #{token.name}"
      else
        raise FirstSetNotDisjoint,
              "The first_sets of #{@name} are not disjoint."
      end
    end

    #Return a Token sequence that is a legal instance of
    #  a concatenation rule
    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
    #@eskimobear.specification
    # T, input token sequence
    # et, token at the head of T
    # r_def, list of terms in rule
    # r_term, term at the head of r_def
    # S, sub-sequence matching rule
    # E, sequence of error tokens
    #
    # Init : length(T) > 0
    #        length(E) = 0
    #        length(S) = 0
    # Next : r_def, et
    #        when r_def = []
    #          S
    #        when r_term.terminal?
    #          when match_terminal(r_term, et)
    #            S' = S + et
    #            T' = T - et
    #            r_def' = r_def - r_term
    #          otherwise
    #            E + et
    #        when r_term.nonterminal?
    #          when can_parse?(r_def, T)
    #            S' = parse(r_def, T)
    #            T' = T - S'
    #          otherwise
    #            E + et
    def parse_and_then(tokens, rules, tree)
      result = build_parse_result([], tokens, tree)
      @ebnf.term_list.each_with_object(result) do |i, acc|
        rule = rules.get_rule(i.rule_name)
        parse_result = rule.parse(acc[:rest], rules, acc[:tree])
        acc[:parsed_seq].concat(parse_result[:parsed_seq])
        acc[:rest] = parse_result[:rest]
      end
    end

    #Return a Token sequence that is a legal instance of
    #  an option rule
    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
    #@eskimobear.specification
    # T, input token sequence
    # et, token at the head of T
    # r, the option rule
    # r_term, single term of the rule
    # S, sub-sequence matching rule
    # E, sequence of error tokens
    #
    # Init : length(T) > 0
    #        length(E) = 0
    #        length(S) = 0
    # Next : r_term, et
    #        when r_term.terminal?
    #          when match(r_term, et)
    #            S = et
    #            T - et
    #        when r_term.nonterminal?
    #           S = parse(r, T)
    #           T - S
    #        when match_follow_set?(r, et)
    #           S = []
    #           T
    #        otherwise
    #          E + et
    def parse_maybe(tokens, rules, tree)
      term = @ebnf.term
      term_rule = rules.get_rule(term.rule_name)
      begin
        acc = term_rule.parse(tokens, rules)
        acc.store(:tree, tree.merge(acc[:tree]))
        acc
      rescue InvalidSequenceParsed => pe
        parse_none(tokens, pe, tree)
      end
    end

    def parse_none(tokens, exception, tree)
      lookahead = tokens.first
      if @follow_set.include? lookahead.name
        return build_parse_result([], tokens, tree)
      else
        raise exception
      end
    end

    #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
    #@param rules [Eson::RuleSeq] list of possible rules
    #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence of
    #  tokens as :parsed_seq and the rest of the Token sequence as :rest
    #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
    #@eskimobear.specification
    # T, input token sequence
    # et, token at the head of T
    # r, the option rule
    # r_term, single term of the rule
    # S, sub-sequence matching rule
    # E, sequence of error tokens
    #
    # Init : length(T) > 0
    #        length(E) = 0
    #        length(S) = 0
    # Next : r_term, et
    #        S' = S + match_maybe(r_term, T)
    #        T' = T - S'
    #        when S = []
    #          S, T
    #        when T = []
    #          S, T
    #        otherwise
    #          E + et
    def parse_many(tokens, rules, tree)
      acc = parse_maybe(tokens, rules, tree)
      is_tokens_empty = acc[:rest].empty?
      is_rule_nulled = acc[:parsed_seq].empty?
      if is_tokens_empty || is_rule_nulled
        acc
      else
        begin
          acc.merge(parse_many(
                      acc[:rest],
                      rules,
                      acc[:tree])) do |key, old, new|
            case key
            when :parsed_seq
              old.concat(new)
            when :rest, :tree
              new
            end
          end
        rescue InvalidSequenceParsed => pe
          acc
        end
      end
    end

    #Compute the start rxp of nonterminal rules
    #@param rules [Eson::RuleSeq] the other rules making
    #  up the grammar
    #@return [Eson::RuleSeq::Rule] the mutated Rule
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
  end
end
