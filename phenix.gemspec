# frozen_string_literal: true
require_relative 'lib/phenix/version'

Gem::Specification.new do |s|
  s.name          = 'phenix'
  s.version       = Phenix::VERSION
  s.authors       = ['Pierre Schambacher']
  s.email         = ['pschambacher@zendesk.com']

  s.summary       = 'Read a dynamic database.yml file and allow you to drop/create the database on demand.'
  s.homepage      = 'https://github.com/zendesk/phenix'
  s.files         = Dir.glob('lib/**/*')
  s.require_paths = ['lib']

  s.add_dependency 'bundler'
  s.add_dependency 'activerecord', '>= 4.2', '< 6.1'

  s.add_development_dependency 'rake', '>= 12.3.3'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'mysql2'
  s.add_development_dependency 'single_cov'
end
