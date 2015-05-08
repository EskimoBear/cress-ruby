require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/eson_grammars.rb'

describe "Eson::EsonGrammars" do
  
  subject {Eson::EsonGrammars}

  before do
    SEvalMod = Module.new do
      def s_eval(token)
        add_s_attr_item(token, :value, token.lexeme.to_s)
      end
    end
    @synth_action = :s_eval
    @cfg = subject.e5
    @attr_maps = [{
                    :attr => :value,
                    :type => :s_attr,
                    :action_mod => SEvalMod,
                    :actions => [:s_eval],
                    :terms => [:string, :variable_identifier]
                  },
                  {
                    :attr => :line_no,
                    :type => :i_attr,
                    :terms => [:All]
                  }]
    @attr_grammar = subject.build_attr_grammar(
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
      @attr_grammar.must_be_kind_of Struct::Formatter
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
    it "s_attr computation rules" do
      @attr_grammar.string.actions.must_include @synth_action
      @attr_grammar.string.must_respond_to @synth_action
      @attr_grammar.variable_identifier.actions.must_include @synth_action
      @attr_grammar.variable_identifier.must_respond_to @synth_action
    end
    it "apply s-attributes" do
      token = @attr_grammar.variable_identifier.match_token("$var")
      token.attributes[:s_attr][:value].must_equal "$var"
    end
  end

  describe "failing_attribute_grammars" do
    it "actions" do
    end
  end
end
