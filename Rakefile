task default: %w[test]

task :test do
  ruby "test/ast_test.rb"
  ruby "test/variable_store_test.rb"
  ruby "test/dote_fmt_test.rb"
  ruby "test/parse_tree_test.rb"
  ruby "test/attr_grammar_test.rb"
  ruby "test/dote_grammars_test.rb"
  ruby "test/dote_test.rb"
  ruby "test/program_errors_test.rb"
  ruby "test/tokenizer_test.rb"
  ruby "test/rule_seq_test.rb"
  ruby "test/rule_test.rb"
  ruby "test/token_seq_test.rb"
  ruby "test/cli_test.rb"
end

task :test_utils do
  ruby "test/respondent_test.rb"
  ruby "test/typed_seq_test.rb"
end
