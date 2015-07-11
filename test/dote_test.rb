require 'vert'
require_relative './test_helpers.rb'

describe Dote do

  include TestHelpers

  before do
    @empty_program = get_empty_program
    @unknown_special_form_program = get_unknown_special_form_program
    @malformed_program = get_malformed_program
    @valid_program = get_tokenizer_sample_program
    @dir_path = get_code_gen_dir
    @object_code_path = File.join(@dir_path, "object_code.dt")
  end

  describe "#compile" do
    before do
      @lang = Dote::DoteGrammars.dote_fmt
    end
    after do
      FileUtils.rm_rf(@dir_path)
    end
    it "valid_program" do
      Dote.compile(@valid_program, @lang, @object_code_path).must_be_nil
      FileTest.exist?(@object_code_path).must_equal true
    end
    it "empty_program" do
      Dote.compile(@empty_program, @lang, @object_code_path).must_be_nil
      FileTest.exist?(@object_code_path).must_equal false
    end
    it "malformed_program" do
      proc {Dote.compile(@malformed_program, @lang, @object_code_path)}.must_raise Dote::SyntaxError
    end
    it "program_with_unknown_special_forms" do
      proc {Dote.compile(@unknown_special_form_program, @lang, @object_code_path)}
        .must_raise Dote::TokenPass::TokenSeq::UnknownSpecialForm
    end
  end

  describe "#source_to_env" do
    it "valid_program" do
      Dote.source_to_env(@valid_program).must_be_instance_of Hash
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
      @env = Dote.source_to_env(@valid_program, Dote::DoteGrammars.dote_fmt)
    end
    it "outputs file" do
      Dote.build_object_code(@env, Dote::DoteGrammars.dote_fmt, @object_code_path)
      FileTest.exist?(@object_code_path).must_equal true
    end
    after do
      FileUtils.rm_rf(@dir_path)
    end
  end

end
