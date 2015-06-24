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
      @input_file_path = File.join(get_code_gen_dir, 'dotef_input.dt')
      FileUtils.cp(get_test_input_path('dotef_input'), @input_file_path)
    end
    it "rewrites input file" do
      `#{@path} fmt #{@input_file_path}`
      @output = load_test_inputs('dotef_output')
      FileUtils.identical?(@input_file_path,
                           get_test_input_path('dotef_output')).must_equal true
    end
    describe "writes_new_file" do
      it "includes file extension" do
        json_file = 'fmt_output.json'
        `#{@path} fmt #{@input_file_path} #{json_file}`
        FileUtils.identical?(json_file,
                             get_test_input_path('dotef_output')).must_equal true
        FileUtils.rm(json_file)
      end
      it "without file extension" do
        file_input_path = 'fmt_output'
        output_file = file_input_path.concat('.dt')
        `#{@path} fmt #{@input_file_path} #{file_input_path}`
        FileUtils.identical?(output_file,
                             get_test_input_path('dotef_output')).must_equal true
        FileUtils.rm(output_file)
      end
    end
    after do
      FileUtils.rm_rf(get_code_gen_dir)
    end
  end
end
