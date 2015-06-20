require 'minitest/autorun'
require 'minitest/pride'
require_relative '../bin/cli.rb'

describe "cli" do
  before do
    @path = File.expand_path('../../bin/cli.rb', __FILE__)
  end
  it "prints default usage text" do
    `#{@path}`.must_equal CLI_USAGE
  end
end
