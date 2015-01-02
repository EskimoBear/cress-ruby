require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson.rb'

describe Eson do

  before do
    @valid_eson = File.open(File.expand_path('../../test/eson_files/valid.eson', __FILE__)).read 
  end

  describe "given valid eson" do
    it ".read" do
      Eson.read(@valid_eson).must_be_nil
    end
  end
end


