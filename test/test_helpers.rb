require_relative '../lib/eson'

module TestHelpers

  extend self
  
  def get_valid_eson
    load_test_inputs('valid')
  end

  def get_unknown_special_form_program
    load_test_inputs('unknown_special_form')
  end

  def get_tokenizer_sample_program
    load_test_inputs('tokenizer_sample')
  end

  def get_empty_program
    "{}"
  end

  def get_invalid_program
    "{\"invalid\": (}"
  end

  def get_token_sequence
    Eson::TokenPass::Tokenizer.tokenize_program(get_tokenizer_sample_program)
      .first
      .add_line_numbers
      .verify_special_forms
      .tokenize_variable_identifiers
      .tokenize_special_forms
      .tokenize_proc_identifiers
      .tokenize_word_forms
      .label_sub_strings
      .insert_string_delimiters
  end
  
  private

  def load_test_inputs(name)
    file = File.join('../../test/eson_inputs', "#{name}.eson")
    File.open(File.expand_path(file, __FILE__)).read 
  end
end
