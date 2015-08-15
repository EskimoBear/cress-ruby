module Dote::DoteGrammars

  # @return [Struct] attribute grammar that formats Dote programs
  # for display on stdout
  def display_fmt
    RuleSeq.assign_attribute_grammar(
      tokenizer_cfg,
      [DisplayFormat],
      [{
         :attr => :line_no,
         :type => :s_attr,
         :terms => [:All]
       },
       {
         :attr => :indent,
         :type => :s_attr,
         :terms => [:All]
       },
       {
         :attr => :spaces_after,
         :type => :s_attr,
         :terms => [:colon]
       }])
  end

  # Attribute actions module for {Dote::DoteGrammars#display_fmt} grammar
  module DisplayFormat

    include ITokenizer

    def env_init
      [{:attr => :line_no, :attr_value => 1},
       {:attr => :indent, :attr_value => 0},
       {:attr => :spaces_after, :attr_value => 1}]
    end

    # Evaluates the s-attributes for this grammar during tokenization.
    # @param (see Dote::DoteGrammars::ITokenizer#eval_s_attributes)
    # @return (see Dote::DoteGrammars::ITokenizer#eval_s_attributes)
    def eval_s_attributes(envs, token, token_seq)
      update_line_no_env(envs, token)
      update_indent_env(envs, token)
    end

    def update_line_no_env(envs, token)
      end_line_tokens = [:program_start,
                         :array_start,
                         :element_divider,
                         :declaration_divider]
      start_line_tokens = [:program_end,
                           :array_end]
      if end_line_tokens.include?(token.name)
        increment_env_attr(envs, :line_no, 1)
      elsif start_line_tokens.include?(token.name)
        increment_env_attr(envs, :line_no, 1)
        token.assign_envs(envs)
      end
    end

    def increment_env_attr(envs, attr, inc)
      env = envs.find{|i| i[:attr] == attr}
      env[:attr_value] = env[:attr_value] + inc
    end

    def update_indent_env(envs, token)
      end_line_tokens = [:program_start,
                         :array_start]
      start_line_tokens = [:program_end,
                           :array_end]
      if end_line_tokens.include?(token.name)
        increment_env_attr(envs, :indent, 1)
      elsif start_line_tokens.include?(token.name)
        increment_env_attr(envs, :indent, -1)
        token.assign_envs(envs)
      end
    end
  end
end
