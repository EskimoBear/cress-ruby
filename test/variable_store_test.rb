require_relative './test_helpers'
require_relative '../lib/dote/dote_grammars'

describe Dote::DoteGrammars::VariableStore do

  include TestHelpers
  subject {Dote::DoteGrammars.var_store}

  before do
    @tree_eval = Dote.compile(load_test_inputs('variable_sample'), subject)
    @store = @tree_eval[:store]
  end

  describe "creates_variables_in_store" do
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
