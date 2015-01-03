require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'

class TokenizerTest < MiniTest::Unit::TestCase

  include TestHelpers

  def setup
    @valid_eson = get_valid_eson
  end
  
end
