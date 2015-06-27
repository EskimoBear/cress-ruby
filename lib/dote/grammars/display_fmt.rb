module Dote::DoteGrammars

  #@return [Struct] attribute grammar that formats Dote programs
  #for display on stdout
  def display_fmt
    RuleSeq.assign_attribute_grammar(
      "Display_Fmt",
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

    def env_init
      [{:attr => :line_no, :attr_value => 1},
       {:attr => :indent, :attr_value => 0},
       {:attr => :spaces_after, :attr_value => 1}]
    end

    def eval_tree_attributes(tree)
      tree
    end

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

    def get_program_snippet(line_no, token_seq)
      display_program(
        TokenSeq.new(
        token_seq.select{|i| i.get_attribute(:line_no) == line_no}))
    end

    def display_program(token_seq)
      if token_seq.none?{|i| i.get_attribute(:line_no).nil?}
        program_lines =
          token_seq.slice_when do |t0, t1|
          t0.get_attribute(:line_no) != t1.get_attribute(:line_no)
        end
          .map do |ts|
          [ ts.first.get_attribute(:line_no),
            ts.first.get_attribute(:indent),
            ts.each_with_object("") do |j, acc|
              acc.concat(j.lexeme.to_s)
              unit = j.get_attribute(:spaces_after)
              space = unit.nil? ? "" : get_spaces(unit)
              acc.concat(space)
            end
          ]
        end
        max_line = program_lines.length
        program_lines.map do |i|
          "#{get_line(i[0], max_line)}#{get_indentation(i[1])}#{i[2]}\n"
        end
          .reduce(:concat)
          .prepend("\n")
      end
    end

    def get_line(line_no, max_line_no)
      padding = max_line_no.to_s.size - line_no.to_s.size
      "#{get_spaces(padding)}#{line_no}:"
    end

    def get_spaces(units)
      repeat_string(units, " ")
    end

    def get_indentation(units)
      repeat_string(units, "  ")
    end

    def repeat_string(reps, string)
      acc = String.new
      reps.times{acc.concat(string)}
      acc
    end
  end
end
