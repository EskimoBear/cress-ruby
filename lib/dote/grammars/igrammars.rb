require_relative '../../../utils/respondent'

module Dote::DoteGrammars
  module ITokenizer

    # Hook method which creates array containing the initial values of
    # the s_attributes for the grammar.
    # @return [Array<Hash>]
    # @example Concrete implementation
    # def env_init
    #   [{:attr => :line_no, :attr_value => 1}]
    # end
    def env_init
    end

    # Hook method called during tokenization for setting the s_attributes
    # value on each token. It will be called with each token and makes
    # the env_init array and the remaining tokens in the program avaiable as
    # context.
    # @param envs [Hash] The env_init Array
    # @param token [Token]
    # @param token_seq [TokenSeq]
    # @return [nil]
    def eval_s_attributes(envs, token, token_seq)
    end

    # @return [Array] array of s-attributes given in env_init
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
  end

  module ISemantics

    include IParser

    def convert_to_ast(tree)
      tree
    end

    def build_store(ast)
      {}
    end

    def transform_to(new_rule_name, tree)
      old_rule = self.get_rule(tree.name)
      new_rule = self.get_rule(new_rule_name)
      diff = old_rule.syntax_diff(new_rule)
      unless diff[:rename].nil?
        tree.replace_root(new_rule)
      end
      unless diff[:remove].empty?
        diff[:remove].each do |i|
          tree.delete_tree(i)
        end
      end
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
