require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'
require_relative './test_helpers.rb'

describe Eson do

  include TestHelpers
  
  before do
    @empty_program = get_empty_program
    @unknown_special_form_program = get_unknown_special_form_program
  end

  describe "given empty program" do
    it ".compile" do
      Eson.compile(@empty_program).must_be_nil
    end
  end

  describe "program with unknown special forms" do
    it ".compile" do
      proc {Eson.compile(@unknown_special_form_program)}.must_raise Eson::Pass::SpecialFormError 
    end
  end
end


