require_relative './respondent'
require_relative './parse_tree'
require_relative './program_errors'

module Parser

  include ProgramErrors
  extend Respondent

  NoMatchingFirstSet = Class.new(StandardError)
  FirstSetNotDisjoint = Class.new(StandardError)

  uses :name, :term_names, :terminal?, :follow_set
  
  #Return a legal instance of a rule
  #@param tokens [Eson::TokenPass::TokenSeq] a token sequence
  #@param grammar [Struct] context free grammar or attribute grammar
  #@return [Hash<Symbol, TokenSeq>] returns matching sub-sequence in
  #                                 tokens as :parsed_seq, as a tree
  #                                 in :tree and the rest as :rest
  #@raise [InvalidSequenceParsed] if no legal sub-sequence can be found
  def parse(tokens, grammar, tree=nil)
    if self.terminal?
      acc = parse_terminal(tokens, tree)
    else
      if tree.nil?
        tree = Parser::ParseTree.new
      end
      tree.insert(self)
      acc = if self.alternation_rule?
              parse_any(tokens, grammar, tree)
            elsif self.concatenation_rule?
              parse_and_then(tokens, grammar, tree)
            elsif self.option_rule?
              parse_maybe(tokens, grammar, tree)
            elsif self.repetition_rule?
              parse_many(tokens, grammar, tree)
            end
      acc[:tree].close_active
      acc
    end
  end

  #(see #parse)
  def parse_terminal(tokens, tree)
    lookahead = tokens.first
    if self.name == lookahead.name
      leaf = Parser::ParseTree.new(lookahead)
      tree = if tree.nil?
               leaf
             else
               tree.merge(leaf)
             end
      build_parse_result([lookahead], tokens.drop(1), tree)
    else
      raise InvalidSequenceParsed,
            parse_terminal_error_message(self.name, lookahead, tokens)
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

  #Return a legal instance of an alternation rule
  #@param (see #parse)
  #@return (see #parse)
  #@raise (see #parse)
  #@eskimobear.specification
  # T, input token sequence
  # et, token at the head of T
  # r, rule
  # r_def, list of terms in rule
  # S, sub-sequence matching rule
  # E, sequence of error tokens
  # A, Tree
  #
  # Init : length(T) > 0
  #        length(E) = 0
  #        length(S) = 0
  #        A is the empty tree
  # Next : r_term = match_first_set(r_def, et)
  #        when r_term.terminal?
  #            S' = S + et
  #            A' = A + add_node(r, et)
  #            T' = T - et
  #        when r_term.nonterminal?
  #          when r_term.can_parse?(r_def, T)
  #            S' = r_term.parse(r_def, T)
  #            A' = A + add_node(r, S')
  #            T' = T - S'
  #            r_def' = []
  #          otherwise
  #            E' = E + et
  #       when r_term not found
  #          E' = E + et
  def parse_any(tokens, grammar, tree)
    lookahead = tokens.first
    term = first_set_match(lookahead, grammar)
    rule = grammar.get_rule(term)
    rule.parse(tokens, grammar, tree)
  rescue NoMatchingFirstSet => e
    raise InvalidSequenceParsed,
          first_set_error_message(lookahead, tokens)
  end

  #@param token [Eson::LexemeCapture::Token] token
  #@param grammar [Eson::RuleSeq] list of possible rules
  #@return [Terminal, NonTerminal] term that has a first_set
  #  which includes the given token.
  #@raise [FirstSetNotDisjoint] if more than one term matches
  #@raise [NoMatchingFirstSet] if no terms match
  def first_set_match(token, grammar)
    terms = get_matching_first_sets(token, grammar)
    case terms.length
    when 1
      terms.first
    when 0
      raise NoMatchingFirstSet
    else
      raise FirstSetNotDisjoint,
            "The first_sets of #{self.name} are not disjoint."
    end
  end

  def get_matching_first_sets(token, grammar)
    self.term_names.find_all do |i|
      rule = grammar.get_rule(i)
      rule.first_set.include? token.name
    end
  end

  #Return a legal instance of a concatenation rule
  #@param (see #parse)
  #@return (see #parse)
  #@raise (see #parse)
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
  #          when T = []
  #            E' = E + et
  #          when match_terminal(r_term, et)
  #            S' = S + et
  #            T' = T - et
  #            r_def' = r_def - r_term
  #          otherwise
  #            E' = E + et
  #        when r_term.nonterminal?
  #          when can_parse?(r_def, T)
  #            S' = parse(r_def, T)
  #            T' = T - S'
  #          otherwise
  #            E' = E + et
  def parse_and_then(tokens, grammar, tree)
    result = build_parse_result([], tokens, tree)
    @ebnf.term_list.each_with_object(result) do |i, acc|
      if acc[:rest].empty?
        raise InvalidSequenceParsed,
              exhausted_tokens_error_message(i.rule_name,
                                             acc[:parsed_seq])
      end
      rule = grammar.get_rule(i.rule_name)
      parse_result = rule.parse(acc[:rest], grammar, acc[:tree])
      acc[:parsed_seq].concat(parse_result[:parsed_seq])
      acc[:rest] = parse_result[:rest]
    end
  end

  #Return a legal instance of an option rule
  #@param (see #parse)
  #@return (see #parse)
  #@raise (see #parse)
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
  def parse_maybe(tokens, grammar, tree)
    term = self.term_names.first
    term_rule = grammar.get_rule(term)
    begin
      acc = term_rule.parse(tokens, grammar)
      acc.store(:tree, tree.merge(acc[:tree]))
      acc
    rescue InvalidSequenceParsed => pe
      parse_none(tokens, pe, tree, grammar)
    end
  end

  #Insert the nullable token if this is a legal instance of a
  #nullable rule. Raise the given exception otherwise.
  def parse_none(tokens, exception, tree, grammar)
    lookahead = tokens.first
    if self.follow_set.include? lookahead.name
      tree.merge(nullable_tree(grammar))
      return build_parse_result([], tokens, tree)
    else
      raise exception
    end
  end

  def nullable_tree(grammar)
    nullable_token = grammar.get_rule(:nullable).make_token("")
    nullable_token.store_attribute(:to_s, "")
    Parser::ParseTree.new(nullable_token)
  end

  #Return a legal instance of a repetition rule
  #@param (see #parse)
  #@return (see #parse)
  #@raise (see #parse)
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
  def parse_many(tokens, grammar, tree)
    acc = parse_maybe(tokens, grammar, tree)
    is_tokens_empty = acc[:rest].empty?
    is_rule_nulled = acc[:parsed_seq].empty?
    if is_tokens_empty || is_rule_nulled
      acc
    else
      begin
        partial = parse_many(acc[:rest], grammar, acc[:tree])
        acc.merge(partial) do |key, old, new|
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
end
