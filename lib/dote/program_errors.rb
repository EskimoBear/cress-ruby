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
  # @return [String] formatted output of program line contained in token_seq
  def print_error_line(invalid_token, token_seq)
    if invalid_token.valid_attribute?(:line_no) &&
       invalid_token.valid_attribute?(:indent)
      line_no = invalid_token.get_attribute(:line_no)
      get_program_snippet(line_no, token_seq)
    else
      String.new
    end
  end

  def get_program_snippet(line_no, token_seq)
    display_program(token_seq.select{|i| i.get_attribute(:line_no) == line_no})
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
