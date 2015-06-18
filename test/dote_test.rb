require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/dote.rb'
require_relative './test_helpers.rb'

describe Dote do

  include TestHelpers
  
  before do
    @empty_program = get_empty_program
    @unknown_special_form_program = get_unknown_special_form_program
    @invalid_program = get_invalid_program
    @valid_program = get_tokenizer_sample_program
  end

  describe "empty program" do
    it ".compile" do
      Dote.compile(@empty_program).must_be_nil
    end
  end

  describe "invalid program" do
    it ".compile" do
      proc {Dote.compile(@invalid_program)}.must_raise Dote::SyntaxError
    end
  end

  describe "program_with_unknown_special_forms" do
    it ".compile" do
      proc {Dote.compile(@unknown_special_form_program)}
        .must_raise Dote::TokenPass::TokenSeq::UnknownSpecialForm
    end
  end
end


