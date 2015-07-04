Gem::Specification.new do |s|
  s.name         = 'dote'
  s.version      = '0.1.0'
  s.date         = '2015-06-18'
  s.summary      = 'Dote compiler'
  s.homepage     = 'https://github.com/EskimoBear/dote'
  s.author       = 'Andre Dickson'
  s.email        = 'andrebcdickson@gmail.com'
  s.license      = 'GPLv3'
  s.files        =  Dir['dote.gemspec', 'lib/dote.rb',
                        'lib/dote/*', 'lib/bin/*',
                        'lib/cli/messages.rb']
  s.executables  = ['dote']
  s.add_runtime_dependency 'oj', '~> 2.10'
  s.add_runtime_dependency 'vert', '~> 0'
  s.add_runtime_dependency 'commander', '~> 4.3'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'pry', '~> 0'
  s.add_development_dependency 'rake', '~> 0'
  s.add_development_dependency 'codeclimate-test-reporter', '~> 0'
end
