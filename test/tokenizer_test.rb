require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'
require_relative '../lib/eson/tokenizer.rb'

describe Eson::TokenPass::Tokenizer do
  subject {Eson::TokenPass}

  describe "with_full_eson_program" do
    before do
      @program = TestHelpers.get_tokenizer_sample_program
      @token_sequence = subject.tokenize_program(@program)
    end
    it "is a TokenSeq" do
      assert @token_sequence.instance_of? Eson::TokenPass::TokenSeq
    end
  end
end
