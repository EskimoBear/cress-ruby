require 'minitest/autorun'
require 'minitest/pride'
require_relative './test_helpers.rb'

describe Dote::SyntaxPass do

  include TestHelpers

  subject {Dote::SyntaxPass}

  describe "valid_token_seq" do
    it "creates_tree" do
      tree = get_parse_tree
      tree.must_be_instance_of Parser::ParseTree
      tree.closed?.must_equal true
    end
  end
end
