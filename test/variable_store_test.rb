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
    it "bind operator variables" do
      @store.member?(:V_bool).must_equal true
      @store.member?(:V_attribute).must_equal true
      @store.member?(:V_sub).must_equal true
      @store.member?(:V_variable).must_equal true
      @store.member?(:V_procedure_application).must_equal true
    end
    it "let param variables" do
      @store.member?(:V_var).must_equal true
      @store.member?(:V_var1).must_equal true
    end
  end

  describe "create_values_in_store" do
    it "from attributes" do
      @store[:V_bool].must_be_instance_of Dote::TypeSystem::BooleanType
      @store[:V_bool].to_val.must_equal true
      @store[:V_attribute].must_be_instance_of Dote::TypeSystem::NumberType
      @store[:V_attribute].to_val.must_equal 87
      @store[:V_variable].must_be_instance_of Dote::TypeSystem::StringType
      @store[:V_variable].to_val.must_equal "The value of values"
      @store[:V_procedure_application].must_be_instance_of Dote::TypeSystem::ProcedureType
    end
    it "unbound let params" do
      @store[:V_var].must_be_instance_of Dote::TypeSystem::UnboundType
      @store[:V_var1].must_be_instance_of Dote::TypeSystem::UnboundType
    end
  end

  describe "variable_to_variable_binding" do
    it "standalone identifiers" do
      @store[:V_sub].must_be_instance_of Dote::TypeSystem::VarType
    end
  end
end
