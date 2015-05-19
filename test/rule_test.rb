require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/rule.rb'
require_relative '../lib/eson/token_pass'

describe Eson::Rule do

  subject {Eson::Rule}
  let(:ast) {Eson::Rule::AbstractSyntaxTree}
  let(:token) {Eson::LexemeCapture::Token}
  let(:token_seq) {Eson::TokenPass::TokenSeq}
  let(:rule_seq) {Eson::RuleSeq.new([subject.new(:rule_1, /RU/),
                                               subject.new(:rule_2, /LE/),
                                               subject.new(:rule_3, /RL/)])}

  #@param parse_result [Hash] result of Rule#parse function
  def verify_types(parse_result)
    parse_result_check = parse_result.instance_of? Hash
    parsed_seq_check = parse_result[:parsed_seq].instance_of? token_seq
    rest_check = parse_result[:rest].instance_of? token_seq
    tree_check = parse_result[:tree].instance_of? ast
    parse_result_check && parsed_seq_check && rest_check && tree_check
  end

  #@param tokens [TokenSeq] input to parse
  #@param parse_result [Hash] output of parse
  #@param split_pnt [Integer] length of accepted sequence
  def verify_accepted_tokens(tokens, parse_result, split_pnt)
    parsed_seq_check = parse_result[:parsed_seq].eql? tokens.take(split_pnt)
    rest_check = parse_result[:rest].eql? tokens.drop(split_pnt)
    parsed_seq_check && rest_check
  end
  
  describe "#parse" do
    before do
      @rules = rule_seq.make_alternation_rule(
        :root_rule,
        [:rule_2, :rule_1])
               .make_terminal_rule(:nullable, /""/)
      @root_rule = @rules.get_rule(:root_rule)
      @init_tree = ast.new(@root_rule)
    end
    describe "terminal_rule" do
      before do
        @rule = subject.new_terminal_rule(:token_name, /RULE/)
        @valid_token = token.new(:lexeme, :token_name)
        @valid_token_seq = token_seq.new([@valid_token])
        @invalid_token = token.new(:lexeme, :invalid_token_name)
        @invalid_token_seq = @valid_token_seq.clone.unshift(@invalid_token)
      end
      describe "with_valid_token" do
        before do
          @parse_result = @rule.parse(@valid_token_seq, @rules)
          @tree = @parse_result[:tree]
        end
        it "has correct types" do
          verify_types(@parse_result).must_equal true
        end
        it "accepted tokens" do
          verify_accepted_tokens(@valid_token_seq, @parse_result, 1).must_equal true
        end
        describe "without tree" do
          it "tree is leaf" do
            @tree.leaf?.must_equal true
          end
          it "tree is closed" do
            @tree.closed?.must_equal true
          end
        end
        describe "with tree" do
          before do
            @parse_result = @rule.parse(@valid_token_seq, rule_seq, @init_tree)
            @tree = @parse_result[:tree]
          end
          it "is open" do
            @tree.closed?.must_equal false
          end
          it "has correct root" do
            @tree.root_value.must_equal @root_rule
          end
          it "has :token_name child" do
            @tree.has_child?(:token_name).must_equal true
          end
        end
      end
      it "with invalid token" do
        proc {@rule.parse(@invalid_token_seq, rule_seq)}
          .must_raise Eson::Rule::InvalidSequenceParsed
      end
    end
    describe "alternation_rule" do
      before do
        @rules = rule_seq.make_alternation_rule(:terminal_rule, [:rule_2, :rule_1])
        @rule = @rules.get_rule(:terminal_rule)
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_3)]
        @valid_token_seq = token_seq.new(@sequence)
        @invalid_token_seq = token_seq.new @sequence.reverse
      end
      describe "only_terminals" do
        describe "with_valid_tokens" do
          before do
            @parse_result = @rule.parse(@valid_token_seq, @rules)
            @tree = @parse_result[:tree]
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accepted tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 1).must_equal true
          end
          describe "without tree" do
            it "has root" do
              @tree.root_value.must_equal @rule
            end
            it "has :rule_1 child" do
              @tree.has_child?(:rule_1).must_equal true
            end
            it "tree is closed" do
              @tree.closed?.must_equal true
            end
          end
          describe "with tree" do
            before do
              @tree = @rule.parse(@valid_token_seq, @rules, @init_tree)[:tree]
              @terminal_rule = @tree.children.first
            end
            it "has root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has :terminal_rule child" do
              @tree.has_child?(:terminal_rule).must_equal true
            end
            it "has :rule_1 ancestor" do
              @terminal_rule.has_child?(:rule_1).must_equal true
            end
            it "tree is closed" do
              @tree.closed?.must_equal false
            end
          end
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
      describe "with_nonterminals" do
        before do
          @rules = @rules.make_alternation_rule(:nonterminal_rule, [:terminal_rule, :rule_3])
          @rule = @rules.get_rule(:nonterminal_rule)
          @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_4)]
          @valid_token_seq = token_seq.new @sequence
          @invalid_token_seq = token_seq.new @sequence.reverse
        end
        describe "with_valid_tokens" do
          before do
            @parse_result = @rule.parse(@valid_token_seq, @rules)
            @tree = @parse_result[:tree]
            @terminal_rule_node = @tree.children.first
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accepted tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 1).must_equal true
          end
          it "has root" do
            @tree.root_value.must_equal @rule
            @tree.active_node.value.must_equal @rule
          end
          it "has three levels" do
            @tree.height.must_equal 3
          end
          it "is closed" do
            @tree.closed?.must_equal true
          end
          it "has :terminal_rule child" do
            @tree.degree.must_equal 1
            @tree.has_child?(:terminal_rule).must_equal true
          end
          it "has :rule_1 descendant" do
            @terminal_rule_node.has_child?(:rule_1).must_equal true
            @terminal_rule_node.degree.must_equal 1
          end
          describe "with_tree" do
            before do
              @tree = @rule.parse(@valid_token_seq, @rules, @init_tree)[:tree]
              @nonterminal_rule_node = @tree.children.first
              @terminal_rule_node = @nonterminal_rule_node.children.first
            end
            it "has root" do
              @tree.root_value.must_equal @root_rule
              @tree.active_node.value.must_equal @root_rule
            end
            it "has four levels" do
              @tree.height.must_equal 4
            end
            it "is open" do
              @tree.open?.must_equal true
            end
            it "has :nonterminal child" do
              @tree.has_child?(:nonterminal_rule).must_equal true
            end
            it "has :terminal_rule descendant" do
              @nonterminal_rule_node.degree.must_equal 1
              @nonterminal_rule_node.has_child?(:terminal_rule).must_equal true
            end
            it "has :rule_1 descendant" do
              @terminal_rule_node.degree.must_equal 1
              @terminal_rule_node.has_child?(:rule_1).must_equal true
            end
          end
        end
      end
    end
    describe "concatenation_rule" do
      before do
        @rules = rule_seq.make_concatenation_rule(:terminal_rule, [:rule_1, :rule_2])
        @rule = @rules.get_rule(:terminal_rule)
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
        @valid_token_seq = token_seq.new(@sequence)
        @invalid_token_seq = token_seq.new @sequence.reverse
        @incomplete_token_seq = @valid_token_seq.first(1)
      end
      describe "with_only_terminals" do
        before do
          @parse_result =  @rule.parse(@valid_token_seq, @rules)
          @tree = @parse_result[:tree]
        end
        describe "with valid tokens" do
          it "correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 2).must_equal true
          end
          describe "without tree" do
            it "has correct root" do
              @tree.root_value.must_equal @rule
            end
            it "has correct children" do
              @tree.has_child?(:rule_1).must_equal true
              @tree.has_child?(:rule_2).must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 2
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
          end
          describe "with tree" do
            before do
              @parse_result =  @rule.parse(@valid_token_seq, @rules, @init_tree)
              @tree = @parse_result[:tree]
              @terminal_rule_node = @tree.children.first
            end
            it "has correct root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has :terminal_rule child" do
              @tree.has_child?(:terminal_rule).must_equal true
            end
            it "has :rule_1 descendant" do
              @terminal_rule_node.has_child?(:rule_1).must_equal true
            end
            it "has :rule_2 descendant" do
              @terminal_rule_node.has_child?(:rule_2).must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 3
            end
            it "is open" do
              @tree.open?.must_equal true
            end
          end
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
        it "exhausted tokens while parsing" do
          proc {@rule.parse(@incomplete_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
      describe "with_nonterminals" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:nonterminal_rule, [:terminal_rule, :rule_3])
          @rule = @rules.get_rule(:nonterminal_rule)
          @sequence = @sequence.push(token.new(:lexeme, :rule_3))
          @valid_token_seq = token_seq.new(@sequence)
          @invalid_token_seq = @valid_token_seq.take(2).push(token.new(:lexeme, :rule_1))
        end
        describe "with_valid_tokens" do
          before do
            @parse_result =  @rule.parse(@valid_token_seq, @rules)
            @tree = @parse_result[:tree]
            @terminal_rule_node = @tree.children.first
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accepted tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 3).must_equal true
          end
          describe "without_tree" do
            it "has :nonterminal_rule root" do
              @tree.root_value.must_equal @rule
            end
            it "has correct children" do
              @tree.has_child?(:terminal_rule).must_equal true
              @tree.has_child?(:rule_3).must_equal true
              @tree.degree.must_equal 2
            end
            it "has :rule_1 and :rule_2 descendants" do
              @terminal_rule_node.has_child?(:rule_1).must_equal true
              @terminal_rule_node.has_child?(:rule_2).must_equal true
              @terminal_rule_node.degree.must_equal 2
            end
            it "has height" do
              @tree.height.must_equal 3
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
          end
          describe "with_tree" do
            before do
              @parse_result =  @rule.parse(@valid_token_seq, @rules, @init_tree)
              @tree = @parse_result[:tree]
              @nonterminal_rule_node = @tree.children.first
              @terminal_rule_node = @nonterminal_rule_node.children.first
            end
            it "has correct root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has :nonterminal_rule child" do
              @tree.has_child?(:nonterminal_rule).must_equal true
              @tree.degree.must_equal 1
            end
            it "has correct descendants" do
              @nonterminal_rule_node.has_child?(:terminal_rule).must_equal true
              @terminal_rule_node.has_child?(:rule_1).must_equal true
              @terminal_rule_node.has_child?(:rule_2).must_equal true
              @terminal_rule_node.degree.must_equal 2
              @nonterminal_rule_node.has_child?(:rule_3).must_equal true
              @nonterminal_rule_node.degree.must_equal 2
            end
            it "has correct height" do
              @tree.height.must_equal 4
            end
          end
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
    end
    describe "repetition_rule" do
      before do
        @rules = rule_seq
                 .make_repetition_rule(:terminal_rule, :rule_1)
        @lang = @rules.build_cfg("LANG")
        @rule = @lang.terminal_rule
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_1)]
        @valid_token_seq = token_seq.new(@sequence)
        @follow_sequence = [token.new(:lexeme, :rule_3), token.new(:lexeme, :rule_1)]
        @invalid_sequence = [token.new(:lexeme, :rule_2), token.new(:lexeme, :rule_1)]
        @invalid_token_seq = token_seq.new(@invalid_sequence)
      end
      describe "with_terminals_only" do
        describe "with_valid_tokens" do
          before do
            @parse_result = @rule.parse(@valid_token_seq, @rules)
            @tree = @parse_result[:tree]
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
            end
          it "accepted tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 2).must_equal true
          end
          describe "without_tree" do
            it "has correct root" do
              @tree.root_value.must_equal @rule
            end
            it "has correct children" do
              @tree.has_children?([:rule_1, :rule_1]).must_equal true
              @tree.degree.must_equal 2
            end
            it "has correct height" do
              @tree.height.must_equal 2
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
          end
          describe "with_tree" do
            before do
              @tree = @rule.parse(@valid_token_seq, @rules, @init_tree)[:tree]
              @terminal_rule_node = @tree.children.first
            end
            it "has correct root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has correct children" do
              @terminal_rule_node.has_children?([:rule_1, :rule_1]).must_equal true
              @terminal_rule_node.degree.must_equal 2
            end
            it "has correct height" do
              @tree.height.must_equal 3
            end
            it "is open" do
              @tree.open?.must_equal true
            end
          end
        end
        it "with_invalid_terminal" do
          proc{@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
      describe "with_nonterminals" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:c_rule, [:rule_1, :rule_2])
                   .make_repetition_rule(:nonterminal_rule, :c_rule)
                   .make_concatenation_rule(:top, [:nonterminal_rule, :rule_3])
          @lang = @rules.build_cfg("LANG", :top)
          @rule = @lang.nonterminal_rule
          @sequence  = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
          @valid_once_seq = token_seq.new(@sequence).concat(@invalid_sequence)
          @valid_many_seq = token_seq.new(@sequence)
                             .concat(@sequence)
                             .concat(@invalid_sequence)
          @valid_nulled_seq = token_seq.new(@follow_sequence)
        end
        describe "appears_once" do
          before do
            @parse_result = @rule.parse(@valid_once_seq, @rules)
            @tree = @parse_result[:tree]
            @c_rule_node = @tree.children.first
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_once_seq, @parse_result, 2).must_equal true
          end
          describe "without_tree" do
            it "has correct root" do
              @tree.root_value.must_equal @rule
            end
            it "has :c_rule child" do
              @tree.has_child?(:c_rule).must_equal true
              @tree.degree.must_equal 1
            end
            it "has :rule_1 and :rule_2 descendants" do
              @c_rule_node.has_children?([:rule_1, :rule_2]).must_equal true
              @c_rule_node.degree.must_equal 2
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 3
            end
          end
          describe "with_tree" do
            before do
              @parse_result = @rule.parse(@valid_once_seq, @rules, @init_tree)
              @tree = @parse_result[:tree]
              @non_terminal_node = @tree.children.first
              @c_rule_node = @non_terminal_node.children.first
            end
            it "has correct root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has :nonterminal_rule child" do
              @tree.has_child?(:nonterminal_rule).must_equal true
              @tree.degree.must_equal 1
            end
            it "has :c_rule descendant" do
              @non_terminal_node.has_child?(:c_rule).must_equal true
              @non_terminal_node.degree.must_equal 1
            end
            it "has :rule_1 and :rule_2 descendants" do
              @c_rule_node.has_children?([:rule_1, :rule_2]).must_equal true
              @c_rule_node.degree.must_equal 2
            end
            it "is open" do
              @tree.open?.must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 4
            end
          end
        end
        describe "appears_many_times" do
          before do
            @parse_result = @rule.parse(@valid_many_seq, @rules)
            @tree = @parse_result[:tree]
            @c_rule_node = @tree.children.first
            @c_rule_node_rep = @tree.children[1]
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_many_seq, @parse_result, 4).must_equal true
          end
          it "has root" do
            @tree.root_value.must_equal @rule
          end
          it "has :c_rule child" do
            @tree.has_child?(:c_rule).must_equal true
            @tree.degree.must_equal 2
          end
          it "has :rule_1 and :rule_2 descendants" do
            @c_rule_node.has_children?([:rule_1, :rule_2]).must_equal true
            @c_rule_node.degree.must_equal 2
            @c_rule_node_rep.has_children?([:rule_1, :rule_2]).must_equal true
            @c_rule_node_rep.degree.must_equal 2
          end
          it "is closed" do
            @tree.closed?.must_equal true
          end
          it "has correct height" do
            @tree.height.must_equal 3
          end
        end
        describe "nulled instance" do
          before do
            @parse_result = @rule.parse(@valid_nulled_seq, @rules)
            @tree = @parse_result[:tree]
          end
           it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_nulled_seq, @parse_result, 0).must_equal true
          end
          it "has root" do
            @tree.root_value.must_equal @rule
          end
          it "contains nullable" do
            @tree.contains?(:nullable).must_equal true
          end
          it "is closed" do
            @tree.closed?.must_equal true
          end
        end
        it "with_invalid_tokens" do
          proc{@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
    end
    describe "option_rule" do
      before do
        @rules = rule_seq
                 .make_option_rule(:terminal_rule, :rule_1)
                 .make_terminal_rule(:nullable, /""/)
        @lang = @rules.build_cfg("LANG")
        @rule = @lang.terminal_rule
        @sequence = [token.new(:lexeme, :rule_1), token.new(:lexeme, :rule_2)]
        @valid_token_seq = token_seq.new(@sequence)
        @nulled_sequence = [token.new(:lexeme, :rule_3), token.new(:lexeme, :rule_1)]
        @valid_nulled_seq = token_seq.new(@nulled_sequence)
        @invalid_token_seq = token_seq.new @sequence.reverse
      end
      describe "with_terminals_only" do
        before do
          @parse_result = @rule.parse(@valid_token_seq, @rules)
          @tree = @parse_result[:tree]
        end
        describe "with_valid_tokens" do
          it "correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 1)
          end
          describe "tree" do
            it "has root" do
              @tree.root_value.must_equal @rule
            end
            it "has :rule_1 child" do
              @tree.has_child?(:rule_1).must_equal true
              @tree.degree.must_equal 1
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 2
            end
          end
        end
      end
      describe "with_nonterminals" do
        before do
          @rules = rule_seq
                   .make_concatenation_rule(:c_rule,
                                            [:rule_1, :rule_2])
                   .make_option_rule(:nonterminal_rule, :c_rule)
                   .make_concatenation_rule(:top,
                                            [:nonterminal_rule,
                                             :rule_3])
          @lang = @rules.build_cfg("LANG", :top)
          @rule = @lang.nonterminal_rule
        end
        describe "with_valid_tokens" do
          before do
            @parse_result = @rule.parse(@valid_token_seq, @rules)
            @tree = @parse_result[:tree]
            @c_rule_node = @tree.children.first
          end
          it "correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_token_seq, @parse_result, 2)
          end
          describe "without_tree" do
            it "has root" do
              @tree.root_value.must_equal @rule
            end
            it "has :c_rule child" do
              @tree.has_child?(:c_rule).must_equal true
              @tree.degree.must_equal 1
            end
            it "has :rule_1 and :rule_2 ancestors" do
              @c_rule_node.has_children?([:rule_1, :rule_2]).must_equal true
            end
            it "is closed" do
              @tree.closed?.must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 3
            end
          end
          describe "with_tree" do
            before do
              @parse_result = @rule.parse(@valid_token_seq, @rules, @init_tree)
              @tree = @parse_result[:tree]
              @nonterminal_rule_node = @tree.children.first
              @c_rule_node = @nonterminal_rule_node.children.first
            end
            it "has root" do
              @tree.root_value.must_equal @root_rule
            end
            it "has :nonterminal_rule child" do
              @tree.has_child?(:nonterminal_rule).must_equal true
              @tree.degree.must_equal 1
            end
            it "has :c_rule ancestor" do
              @nonterminal_rule_node.has_child?(:c_rule).must_equal true
              @nonterminal_rule_node.degree.must_equal 1
            end
            it "has :rule_1 and :rule_2 ancestors" do
              @c_rule_node.has_children?([:rule_1, :rule_2]).must_equal true
              @c_rule_node.degree.must_equal 2
            end
            it "is open" do
              @tree.open?.must_equal true
            end
            it "has correct height" do
              @tree.height.must_equal 4
            end
          end
        end
        describe "nulled instance" do
          before do
            @parse_result =  @rule.parse(@valid_nulled_seq, @rules)
            @tree = @parse_result[:tree]
          end
          it "has correct types" do
            verify_types(@parse_result).must_equal true
          end
          it "accept tokens" do
            verify_accepted_tokens(@valid_nulled_seq, @parse_result, 0).must_equal true
          end
          it "has root" do
            @tree.root_value.must_equal @rule
          end
          it "contains nullable" do
            @tree.contains?(:nullable).must_equal true
          end
          it "is closed" do
            @tree.closed?.must_equal true
          end
        end
        it "with invalid tokens" do
          proc {@rule.parse(@invalid_token_seq, @rules)}
            .must_raise Eson::Rule::InvalidSequenceParsed
        end
      end
    end
  end
end
