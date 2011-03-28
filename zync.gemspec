# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'zync/version'

Gem::Specification.new do |s|
  s.name        = 'zync'
  s.version     = Zync::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Lightweight asynchronous Ruby web framework'
  s.description = 'Lightweight asynchronous Ruby web framework'

  s.authors     = ['Peter Kieltyka', 'Kevin Faustino']
  s.email       = ['peter@nulayer.com']
  s.homepage    = 'http://github.com/nulayer/zync'

  s.files        = Dir['README', 'VERSION', 'lib/**/*']
  s.require_path = 'lib'

  # s.add_dependency('zync-gen', [Zync::VERSION])
  s.add_dependency('eventmachine', ['~> 1.0.0.beta.2'])
  s.add_dependency('rack', ['~> 1.2.1'])
  s.add_dependency('rack-mount', ['~> 0.7.1'])
  s.add_dependency('activesupport', ['~> 3.0.5'])
  s.add_dependency('i18n')

  s.add_development_dependency('rspec', ['~> 2.5.0'])
  s.add_development_dependency('timecop', ['~> 0.3.5'])
  s.add_development_dependency('thin')
end
