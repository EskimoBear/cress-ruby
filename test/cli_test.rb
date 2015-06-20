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
  it "prints version" do
    `#{@path} --version`.must_match /dote 0.1.0/
  end
end
