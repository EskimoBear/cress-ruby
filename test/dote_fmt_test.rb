require_relative './test_helpers.rb'

describe "Dote::DoteGrammars::dote_fmt" do

  include TestHelpers

  subject {Dote::DoteGrammars.dote_fmt}

  before do
    @program = get_tokenizer_sample_program
    @ts = get_token_sequence(@program, subject)
    @tree = get_parse_tree(@ts, subject)
  end

  describe "validate_dote_fmt" do
    it "rules have s_attr line_feed" do
      subject.all?{|i| i.s_attr.include? :line_feed}
        .must_equal true
    end
    it "rules have :line_start" do
      subject.all?{|i| i.s_attr.include? :line_start}
        .must_equal true
    end
    it "rules have s_attr to_s" do
      subject.all?{|i| i.s_attr.include? :to_s}
        .must_equal true
    end
  end

  describe "validate_tokens" do
    it "line_feed evaluated" do
      @ts.find_all{|i| i.get_attribute(:line_feed) == true}
        .length.must_equal 16
    end
    it "to_s evaluated" do
      @ts.none?{|i| i.get_attribute(:to_s).nil?}
        .must_equal true
    end
    it "line_start evaluated" do
      @ts.find_all{|i| i.get_attribute(:line_start) == true}
        .length.must_equal 17
    end
  end

  describe "validate_tree" do
    it "to_s evaluated" do
      @tree.get_attribute(:to_s)
        .must_equal get_tokenizer_sample_program
    end
  end

  describe "validate_generated_code" do
    before do
      @file_name = "code.dt"
      @code_path = File.join(get_code_gen_dir, @file_name)
    end
    it "outputs a file" do
      @code = get_code(@tree, subject, @code_path)
      FileTest.exist?(@code_path).must_equal true
    end
    after do
      FileUtils.rm_rf(get_code_gen_dir)
    end
  end
end
