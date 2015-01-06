require_relative '../lib/eson.rb'
require_relative '../test/test_helpers.rb'
require 'benchmark'

eson_program = TestHelpers.get_tokenizer_eson
thousand_runs = 1000
ten_thousand_runs = 10_000
hundred_thousand_runs = 100_000
  
Benchmark.bmbm do |x|
  x.report("thousand times:") do
    thousand_runs.times do
      Eson::Tokenizer.tokenize_program(eson_program)
    end
  end
  x.report("ten thousand times:") do
    ten_thousand_runs.times do
      Eson::Tokenizer.tokenize_program(eson_program)
    end
  end
  x.report("hundred thousand times:") do
    hundred_thousand_runs.times do;
      Eson::Tokenizer.tokenize_program(eson_program)
    end
  end
end
