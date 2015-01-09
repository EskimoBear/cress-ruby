require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'
require_relative './test_helpers.rb'

class TestEsonParser <  MiniTest::Test

  include TestHelpers
  
  def setup
    @tokens = get_token_sequence
  end

  def test_asm_generated
  end
  
end
