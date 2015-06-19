require_relative 'rule_seq.rb'
require_relative 'typed_seq.rb'
require_relative 'variable_store'
require_relative 'ast'

module Dote
  module DoteGrammars

    extend self

    RuleSeq =  Dote::RuleSeq
    Rule = Dote::Rule

    def proc_prefix_rxp
      /&/
    end

    def string_delimiter_rxp
      /"/
    end

    def attribute_name_rxp
      proc_prefix = proc_prefix_rxp.source
      /\A"[^#{proc_prefix}]+"\z/
    end

    def unreserved_procedure_rxp
      proc_prefix = proc_prefix_rxp.source
      string_delimiter = string_delimiter_rxp.source
      /#{string_delimiter}#{proc_prefix}(.+)#{string_delimiter}\z/
    end

    #@return [E0] eson grammar for lexing keys
    def keys
      reserved = [:let, :ref, :doc]
      RuleSeq.new(make_reserved_keys_rules(reserved))
        .make_terminal_rule(
          :key_delimiter,
          string_delimiter_rxp)
        .make_terminal_rule(
          :unreserved_procedure_identifier,
          unreserved_procedure_rxp)
        .make_alternation_rule(:special_form_identifier, reserved)
        .convert_to_terminal(:special_form_identifier)
        .make_terminal_rule(
          :attribute_name,
          attribute_name_rxp)
        .make_alternation_rule(
          :proc_identifier,
          [:unreserved_procedure_identifier,
           :special_form_identifier])
        .build_cfg("R0")
    end

    def make_reserved_keys_rules(keywords)
      keywords.map do |k|
        if k.is_a?(String) || k.is_a?(Symbol)
          k_name = k.is_a?(Symbol) ? k : k.intern
          k_string = k.is_a?(String) ? k : k.to_s
          Rule.new_terminal_rule(
            k_name,
            Regexp.new(
              string_delimiter_rxp.source
              .concat(proc_prefix_rxp.source)
              .concat(k_string)
              .concat(string_delimiter_rxp.source)))
        end
      end
    end

    # null := "nil";
    def null_rule
      Rule.new_terminal_rule(:null, null_rxp)
    end

    def null_rxp
      /null\z/
    end

    def variable_prefix_rxp
      /\$/
    end

    def variable_identifier_rxp
      variable_prefix = variable_prefix_rxp.source
      word = word_rxp.source
      /#{variable_prefix}#{word}/
    end

    def word_form_rule
      Rule.new_terminal_rule(:word_form, word_form_rxp)
    end

    def word_form_rxp
      word = word_rxp.source
      whitespace = whitespace_rxp.source
      other_chars = other_chars_rxp.source
      /#{word}|#{whitespace}|#{other_chars}/
    end

    def word_rxp
      /[a-zA-Z\-_.\d]+/
    end
    
    def whitespace_rxp
      /[ ]+/
    end

    def other_chars_rxp
      word = word_rxp.source
      variable_prefix = variable_prefix_rxp.source
      whitespace = whitespace_rxp.source
      string_delimiter = string_delimiter_rxp.source
      /[^#{string_delimiter}#{word}#{variable_prefix}#{whitespace}]+/
    end

    # true := "true";
    def true_rule
      Rule.new_terminal_rule(:true, true_rxp)
    end
    
    def true_rxp
      /true\z/
    end
    
    # false := "false";
    def false_rule
      Rule.new_terminal_rule(:false, false_rxp)
    end
    
    def false_rxp
      /false\z/
    end

    # number := JSON_number;
    def number_rule
      Rule.new_terminal_rule(:number, number_rxp)
    end

    def number_rxp
      /\d+/
    end

    # array_start := "[";
    def array_start_rule
      Rule.new_terminal_rule(:array_start, array_start_rxp)
    end

    def array_start_rxp
      /\[/
    end
    
    # array_end := "]";
    def array_end_rule
      Rule.new_terminal_rule(:array_end, array_end_rxp)
    end

    def array_end_rxp
      /\]/
    end
    
    # comma := ",";
    def comma_rule
      Rule.new_terminal_rule(:comma, comma_rxp)
    end

    def comma_rxp
      /\,/
    end

    # declaration_divider := ",";
    def declaration_divider_rule
      Rule.new_terminal_rule(:declaration_divider, comma_rxp)
    end
    
    # colon := ":";
    def colon_rule
      Rule.new_terminal_rule(:colon, colon_rxp)
    end

    def colon_rxp
      /:/
    end
    
    # program_start := "{";
    def program_start_rule
      Rule.new_terminal_rule(:program_start, program_start_rxp)
    end

    def program_start_rxp
      /\{/
    end
    
    # program_end := "}";
    def program_end_rule
      Rule.new_terminal_rule(:program_end, program_end_rxp)
    end

    def program_end_rxp
      /\}/
    end
    
    #@return [E1] eson grammar used for tokenization
    def e1
      rules = [word_form_rule,
               true_rule,
               false_rule,
               null_rule,
               number_rule,
               array_start_rule,
               array_end_rule,
               colon_rule,
               program_start_rule,
               program_end_rule]
      RuleSeq.new(keys.copy_rules.concat(rules))
        .make_terminal_rule(:variable_identifier,
                           variable_identifier_rxp)
        .make_alternation_rule(
          :sub_string,
          [:word_form, :variable_identifier])
        .make_repetition_rule(
          :sub_string_list,
          :sub_string)
        .make_terminal_rule(
          :string_delimiter,
          string_delimiter_rxp)
        .make_concatenation_rule(
          :string,
          [:string_delimiter,
           :sub_string_list,
           :string_delimiter])
        .make_alternation_rule(
          :value,
          [:true,
           :false,
           :null,
           :string,
           :number,
           :array,
           :program])
        .make_terminal_rule(
          :declaration_divider,
          comma_rxp)
        .make_terminal_rule(
          :element_divider,
          comma_rxp)
        .make_concatenation_rule(
          :element_more_once,
          [:element_divider, :value])
        .make_repetition_rule(
          :element_more,
          :element_more_once)
        .make_concatenation_rule(
          :element_list,
          [:value, :element_more])
        .make_option_rule(
          :element_set, :element_list)
        .make_concatenation_rule(
          :array,
          [:array_start, :element_set, :array_end])
        .make_concatenation_rule(
          :call,
          [:proc_identifier, :colon, :value])
        .make_concatenation_rule(
          :attribute,
          [:attribute_name, :colon, :value])
        .make_alternation_rule(
          :declaration,
          [:call, :attribute])
        .make_concatenation_rule(
          :declaration_more_once,
          [:declaration_divider, :declaration])
        .make_repetition_rule(
          :declaration_more,
          :declaration_more_once)
        .make_concatenation_rule(
          :declaration_list,
          [:declaration, :declaration_more])
        .make_option_rule(
          :declaration_set, :declaration_list)
        .make_concatenation_rule(
          :program,
          [:program_start, :declaration_set, :program_end])
        .build_cfg("E1", :program)
    end

    #Grammar which applies default eson formatting to programs.
    #return [Struct] the attribute grammar Format
    def format
      RuleSeq.assign_attribute_grammar(
        "Format",
        e1,
        [Format],
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

    module Format

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

    def esonf
      RuleSeq.assign_attribute_grammar(
        "DotefGen",
        format,
        [DoteF],
        [{
           :attr => :line_feed,
           :type => :s_attr,
           :terms => [:All]
         },
         {
           :attr => :line_start,
           :type => :s_attr,
           :terms => [:All]
         },
         {
           :attr => :to_s,
           :type => :s_attr,
           :terms => [:All]
         }])
    end

    module DoteF

      def generate_source(tree, path)
        default_filename = "code.eson"
        File.open(File.join(path, default_filename), "w") do |f|
          f.write tree.get_attribute(:to_s)
        end
      end

      def eval_tree_attributes(tree)
        super
        build_tree_to_s(tree)
        tree
      end

      def eval_s_attributes(envs, token, token_seq)
        super
        set_line_feed_true(token, token_seq)
        set_to_s(token)
      end

      def set_line_feed_true(token, token_seq)
        end_line_tokens = [:program_start,
                           :array_start,
                           :element_divider,
                           :declaration_divider]
        start_line_tokens = [:program_end,
                             :array_end]
        if end_line_tokens.include?(token.name)
          token.store_attribute(:line_feed, true)
        elsif start_line_tokens.include?(token.name)
          token_seq.last.store_attribute(:line_feed, true)
          set_to_s(token_seq.last)
        end
      end

      def set_to_s(token)
        lexeme = token.lexeme.to_s
        indent = token.get_attribute(:indent)
        spaces_after = token.get_attribute(:spaces_after)
        line_feed = token.get_attribute(:line_feed)
        line_start = token.get_attribute(:line_start)
        string = "#{get_indentation(indent, line_start)}" \
                 "#{lexeme}" \
                 "#{spaces_after.nil? ? "" : " "}" \
                 "#{line_feed.eql?(true) ? "\n" : ""}"
        token.store_attribute(:to_s, string)
      end

      def get_indentation(indent, line_start)
        if line_start
          acc = String.new
          indent.times{acc.concat("  ")}
          acc
        else
          ""
        end
      end

      def build_tree_to_s(tree)
        tree.post_order_traversal do |t|
          unless t.leaf?
            string = t.children.map{|i| i.get_attribute(:to_s)}
                     .reduce(:concat)
            t.store_attribute(:to_s, string)
          end
        end
      end
    end

    def ast_cfg
      RuleSeq.new(format.copy_rules)
        .make_ag_production_rule(:bind)
        .make_ag_production_rule(:apply)
        .make_ag_terminal_rule(:literal_string, [:value])
        .make_ag_production_rule(:interpolated_string)
        .build_cfg("Ast_cfg", :program)
    end

    def ast
      RuleSeq.assign_attribute_grammar(
        "AST",
        ast_cfg,
        [AST, Format],
        [])
    end

    def var_store
      RuleSeq.assign_attribute_grammar(
        "VariableStore",
        ast,
        [VariableStore],
        [])
    end

    alias_method :tokenizer_lang, :format
  end
end