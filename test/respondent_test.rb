require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/eson/respondent'

describe Respondent do

  before do
    Mixin = Module.new do
      extend Respondent
      uses :method1
    end
  end

  it "receiver doesn't include :method1" do
    proc {
      Class.new do
        extend Mixin
        Mixin.validate(self)
      end
    }.must_raise Respondent::MissingMethod
  end

  it "receiver does include :method1" do
    Class.new do
      extend Mixin
      def method1; end
      Mixin.validate self
    end.class.must_equal Class
  end
end
