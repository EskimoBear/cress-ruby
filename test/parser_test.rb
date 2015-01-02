require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'

class TestEsonParser <  MiniTest::Unit::TestCase

  def setup
    @valid_eson = File.open(File.expand_path('../../test/eson_files/valid.eson', __FILE__)).read
  end

  def test_asm_generated
  end
  
end
