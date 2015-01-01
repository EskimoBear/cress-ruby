require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'

describe Eson do

  before do
    @valid_eson = File.open('eson_files/valid.eson').read 
  end

  describe "given valid eson" do
    it ".read" do
      Eson.read(@valid_eson).must_be_nil
    end
  end
end


