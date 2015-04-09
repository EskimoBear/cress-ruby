require 'minitest/autorun'
require 'minitest/pride'

require_relative './test_helpers.rb'
require_relative '../lib/eson.rb'

describe Eson::SyntaxPass do

  include TestHelpers

  subject {Eson::SyntaxPass}

  describe "valid_token_seq" do
    it "succeeds" do
      tree = get_ast[:tree]
      tree.must_be_instance_of Eson::Language::AbstractSyntaxTree
      tree.closed?.must_equal true
    end
  end
end
