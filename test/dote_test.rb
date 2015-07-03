require 'minitest/autorun'
require 'minitest/pride'
require 'vert'
require_relative '../lib/dote.rb'
require_relative './test_helpers.rb'

describe Dote do

  include TestHelpers

  before do
    @empty_program = get_empty_program
    @unknown_special_form_program = get_unknown_special_form_program
    @malformed_program = get_malformed_program
    @valid_program = get_tokenizer_sample_program
  end

  describe "#compile" do
    it "valid_program" do
      Dote.compile(@valid_program).must_be_instance_of Hash
    end

    it "empty_program" do
      Dote.compile(@empty_program).must_be_nil
    end

    it "malformed_program" do
      proc {Dote.compile(@malformed_program)}.must_raise Dote::SyntaxError
    end

    it "program_with_unknown_special_forms" do
      proc {Dote.compile(@unknown_special_form_program)}
        .must_raise Dote::TokenPass::TokenSeq::UnknownSpecialForm
    end
  end

  describe "#source_to_tree" do
    it "valid_program" do
      Dote.source_to_tree(@valid_program).must_be_instance_of Parser::ParseTree
    end
  end

  describe "#operational_semantics" do
    it "outputs Hash env" do
      options = {:required_keys => [:tree], :hash_keys => [:store]}
      Vert.validate?(run_operational_semantics, :keys => options).must_equal true
    end
  end

  describe "#build_object_code" do
    before do
      @tree = Dote.source_to_tree(@valid_program, Dote::DoteGrammars.dote_fmt)
      @env = {tree: @tree}
      @file_name = "object_code.dt"
      @dir_path = get_code_gen_dir
      @object_code_path = File.join(@dir_path, @file_name)
    end
    it "outputs file" do
      Dote.build_object_code(@env, Dote::DoteGrammars.dote_fmt, @dir_path, @file_name)
      FileTest.exist?(@object_code_path).must_equal true
    end
    after do
      FileUtils.rm_rf(get_code_gen_dir)
    end
  end
end
