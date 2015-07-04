require_relative '../../../utils/respondent'

module Dote::DoteGrammars
  module ITokenizer

    def env_init
      [{:attr => :line_no, :attr_value => 1},
       {:attr => :indent, :attr_value => 0},
       {:attr => :spaces_after, :attr_value => 1}]
    end

    def eval_s_attributes(envs, token, token_seq)
    end

    def attributes
      env_init.map{|attr_hash| attr_hash[:attr]}
    end
  end

  module IParser

    include ITokenizer
    extend Respondent

    uses :top_rule

    def parse_tokens(token_seq)
      top_rule.parse(token_seq, self)[:tree]
    end

    def eval_tree_attributes(tree)
    end
  end

  module ISemantics

    include IParser

    def convert_to_ast(tree)
      tree
    end

    def build_store(ast)
      {}
    end
  end

  # Create source files for new code
  module IObjectCode

    include ISemantics

    def generate_code(env)
      String.new
    end

    def make_file(code, output_path)
      path = File.dirname(output_path)
      file_name = File.basename(output_path)
      File.open(File.join(path, file_name), "w") do |f|
        f.write code
      end
    end
  end
end
