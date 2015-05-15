module ProgramErrors

  InvalidSequenceParsed = Class.new(StandardError)
  UnknownSpecialForm = Class.new(StandardError)

  def exhausted_tokens_error_message(expected_token_name,
                                     token_seq)
    "The program is incomplete." \
    " Expected a symbol of type :#{expected_token_name}" \
    " while parsing :#{@name} but there are no more tokens" \
    " to parse."
      .concat(print_error_line(token_seq.last, token_seq))
  end

  def print_error_line(invalid_token, token_seq)
    if invalid_token.valid_attribute?(:line_no) &&
       invalid_token.valid_attribute?(:indent)
      line_no = invalid_token.get_attribute(:line_no)
      token_seq.get_program_snippet(line_no)
    else
      String.new
    end
  end

  def parse_terminal_error_message(expected_token_name,
                                   actual_token,
                                   token_seq)
    "Error while parsing :#{@name}." \
    " Expected a symbol of type :#{expected_token_name} but got a" \
    " :#{actual_token.name} instead."
      .concat(print_error_line(actual_token, token_seq))
  end

  def first_set_error_message(token, token_seq)
    "Error while parsing :#{@name}." \
    " None of the first_sets of :#{@name} contain" \
    " the term :#{token.name}."
      .concat(print_error_line(token, token_seq))
  end

  def unknown_special_form_error_message(token, token_seq)
    "'#{token.lexeme}' is not a known special_form." \
      .concat(print_error_line(token, token_seq))
  end
end
