require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'
require_relative './test_helpers.rb'

describe Eson do

  include TestHelpers
  
  before do
    @valid_eson = get_valid_eson
  end

  describe "given valid eson" do
    it ".read" do
      Eson.read(@valid_eson).must_be_nil
    end
  end
end


