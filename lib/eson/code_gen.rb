module Eson
  module CodeGen

    extend self
    
    def make_file(tree, grammar, path)
      grammar.generate_source(tree, path)
    end
  end
end
