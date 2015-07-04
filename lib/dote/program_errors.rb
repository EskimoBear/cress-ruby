module ProgramErrors

  # Program could not be parsed
  InvalidSequenceParsed = Class.new(StandardError)

  # A special_form unknown to compiler called in program
  UnknownSpecialForm = Class.new(StandardError)

  # Print errors only when required attributes are present in the tokens.
  # These attributes are made available by the attribute grammar
  # {Dote::DoteGrammars.display_fmt}
  # @param invalid_token [Token] the error token
  # @param token_seq [TokenSeq] the tokens in the program
  # @param grammar [ITokenizer]
  # @return [String] formatted output of program line contained in token_seq
  def print_error_line(invalid_token, token_seq, grammar)
    invalid_token
    if display_attributes?(invalid_token, token_seq, grammar)
      get_program_snippet(invalid_token.get_attribute(:line_no), token_seq)
    else
      String.new
    end
  end

  private

  # @param (see #print_error_line)
  # @return [Boolean] true if required s-attributes are present
  def display_attributes?(invalid_token, token_seq, grammar)
    if invalid_token.valid_attribute?(:line_no)
      grammar.attributes.all? do |attr|
        !token_seq.any?{|t| t.get_attribute(:line_no).nil?}
      end
    else
      false
    end
  end

  def get_program_snippet(line_no, token_seq)
    token_snippet = token_seq.select{|i| i.get_attribute(:line_no) == line_no}
    get_formatted_program_lines(split_token_seq_by_lines(token_snippet))
      .reduce(:concat).prepend("\n")
  end

  def split_token_seq_by_lines(token_seq)
    token_seq.slice_when do |t0, t1|
      t0.get_attribute(:line_no) != t1.get_attribute(:line_no)
    end
  end

  def get_formatted_program_lines(line_token_seqs)
    line_tuples = line_token_seqs.map do |ts|
      [ts.first, get_program_line(ts)]
    end
    max_line = line_tuples.last.first.get_attribute(:line_no)
    line_tuples.map do |i|
      "#{get_line_number_column(i.first.get_attribute(:line_no), max_line)}" \
      "#{get_indentation(i.first.get_attribute(:indent))}#{i.last}\n"
    end
  end

  def get_program_line(token_seq)
    token_seq.each_with_object("") do |j, acc|
      acc.concat(j.lexeme.to_s)
      unit = j.get_attribute(:spaces_after)
      space = unit.nil? ? "" : get_spaces(unit)
      acc.concat(space)
    end
  end

  def get_line_number_column(line_no, max_line_no)
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
