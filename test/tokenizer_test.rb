require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe Eson::Tokenizer do

  before do
    @tokenizer_sample = TestHelpers.get_tokenizer_eson
  end

  describe "with valid JSON string input" do
    
    final_token_sequence, final_input_sequence = Eson::Tokenizer.tokenize_program(@tokenizer_sample)
    
    describe "final state" do
      it "has empty input sequence" do
        final_input_sequence.empty?.must_equal true 
      end
      it "has filled token sequence" do
        final_token_sequence.empty?.wont_equal true 
      end
    end
  end

end

class TokenizerTest < MiniTest::Unit::TestCase

  include TestHelpers

end
