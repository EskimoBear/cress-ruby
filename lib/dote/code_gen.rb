module Dote
  module CodeGen

    extend self
    
    def make_file(tree, grammar, path, file_name)
      grammar.generate_source(tree, path, file_name)
    end
  end
end
