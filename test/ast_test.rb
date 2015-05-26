require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers'
require_relative '../lib/eson/eson_grammars.rb'

describe AST do

  subject {Eson::EsonGrammars.ast}

  include TestHelpers

  before do
    @ts = get_tokens(subject)
    @parse_tree = get_parse_tree(@ts, subject)
    @ast = get_ast(@parse_tree, subject)
  end

  it "has no alternation rules" do
    @ast.none? do |i|
      i === :alternation
    end.must_equal true
  end
end
