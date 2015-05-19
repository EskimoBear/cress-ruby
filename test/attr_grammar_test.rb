require 'minitest/autorun'
require 'minitest/pride'
require 'pp'
require_relative '../lib/eson/rule_seq.rb'
require_relative '../lib/eson/eson_grammars.rb'

describe "Eson::RuleSeq" do
  
  subject {Eson::RuleSeq}

  before do
    module Custom
      def custom_action
      end
    end
    @cfg = Eson::EsonGrammars.e1
    @attr_maps = [{
                    :attr => :value,
                    :type => :s_attr,
                    :action_mod => Custom,
                    :actions => [],
                    :terms => [:string, :variable_identifier]
                  },
                  {
                    :attr => :line_no,
                    :type => :i_attr,
                    :terms => [:All]
                  }]
    @env = [{:attr_value => "$var", :attr => :value}]
    @attr_grammar = subject.assign_attribute_grammar(
      "Formatter",
      @cfg,
      @attr_maps)
    @bad_attr_maps = [{
                        :attr => :value,
                        :type => :i_attr,
                        :terms => [:key_string]
                      }]
  end

  describe "valid_attribute_grammar" do
    it "create successfully" do
      @attr_grammar.must_be_kind_of @cfg.class
    end
    it "inherits functions" do
      @attr_grammar.must_respond_to :custom_action
    end
    it "has s_attr list" do
      @attr_grammar.string.s_attr.must_include :value
      @attr_grammar.variable_identifier.s_attr.must_include :value
    end
    it "nonterminals have i_attr" do
      @attr_grammar.productions.all?{|i| i.i_attr.include? :line_no}
        .must_equal true
    end
    it "terminals have no i_attr" do
      terms = @attr_grammar.terminals
      terms.all?{|i| @attr_grammar.send(i).i_attr.nil?}
        .must_equal true
    end
  end

  describe "evaluated attributes" do
    it "token s-attributes" do
      token = @attr_grammar.variable_identifier
              .match_token("$var", @env)
      token.attributes[:value].must_equal "$var"
    end
  end

  describe "failing_attribute_grammars" do
    it "actions" do
    end
  end
end
