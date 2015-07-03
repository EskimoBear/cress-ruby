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

  #Attribute actions module for {Dote::DoteGrammars#display_fmt} grammar
  module DisplayFormat

    include ITokenizer

    def eval_s_attributes(envs, token, token_seq)
      update_line_no_env(envs, token)
      update_indent_env(envs, token)
      set_line_start_true(token, token_seq)
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

    def set_line_start_true(token, token_seq)
      if token_seq.last.nil?
        token.store_attribute(:line_start, true)
      else
        current_line = token.get_attribute(:line_no)
        last_line = token_seq.last.get_attribute(:line_no)
        if current_line != last_line
          token.store_attribute(:line_start, true)
        end
      end
    end
  end
end
