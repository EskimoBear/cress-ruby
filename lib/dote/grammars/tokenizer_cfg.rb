module Dote::DoteGrammars

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
  def keys_cfg
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

  #@return [Struct] cfg used for tokenization
  def tokenizer_cfg
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
    RuleSeq.new(keys_cfg.copy_rules.concat(rules))
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
end
