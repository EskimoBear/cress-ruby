require 'vert'

module Eson

  include Vert
  extend self

  def read(eson_string)
    validate_json(eson_string)
  end
  
end
