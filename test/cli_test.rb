require 'minitest/autorun'
require 'minitest/pride'
require 'fileutils'
require_relative './test_helpers'
require_relative '../bin/dote.rb'

describe "cli" do
  include TestHelpers

  before do
    @path = File.expand_path('../../bin/dote.rb', __FILE__)
  end
  it "prints default usage text" do
    `#{@path}`.must_equal CLI_USAGE
  end
  it "prints version" do
    `#{@path} --version`.must_match /dote 0.1.0/
  end
  describe "fmt" do
    before do
      get_code_gen_dir
      @input_path = get_test_input_path('dotef_input')
    end
    it "rewrites input file" do
      new_input_path = File.join(get_code_gen_dir, 'dotef_input.dt')
      FileUtils.cp(@input_path, new_input_path)
      `#{@path} fmt #{new_input_path}`
      @output = load_test_inputs('dotef_output')
      FileUtils.identical?(new_input_path,
                           get_test_input_path('dotef_output')).must_equal true
    end
    after do
      FileUtils.rm_rf(get_code_gen_dir)
    end
  end
end
