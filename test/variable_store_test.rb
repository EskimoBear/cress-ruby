require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers'
require_relative '../lib/eson/eson_grammars'

describe VariableStore do

  include TestHelpers
  subject {Eson::EsonGrammars.var_store}

  before do
    @ts = get_token_sequence(
      load_test_inputs('variable_sample'),
      subject)
    @tree = get_parse_tree(@ts, subject)
    @tree_eval = get_semantic_eval(@tree, subject)
    @store = @tree_eval[:env][:store]
  end
  
  describe "creates variables in store" do
    it "from attributes" do
      @store.member?(:V_bool).must_equal true
      @store.member?(:V_attribute).must_equal true
      @store.member?(:V_variable).must_equal true
      @store.member?(:V_procedure_application).must_equal true
    end
    it "from let params" do
      @store.member?(:V_var).must_equal true
      @store.member?(:V_var1).must_equal true
    end
  end
end
