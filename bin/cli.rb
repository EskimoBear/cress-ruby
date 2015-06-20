#!/usr/bin/env ruby
require 'rubygems'
require 'commander/import'

CLI_USAGE = "Usage: dote --COMMAND [ARGS]\n"\
            "Hint: pass a file to compile"
GEMSPEC_PATH = File.expand_path('../../dote.gemspec', __FILE__)

gemspec = Gem::Specification::load(GEMSPEC_PATH)

program :name, gemspec.name.to_s
program :version, gemspec.version.to_s
program :description, 'Compiler for the Dote language'

default_command :usage

command :usage do |c|
  c.action do
    $stdout.print CLI_USAGE
  end
end
