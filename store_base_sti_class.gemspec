# frozen_string_literal: true

require_relative 'lib/store_base_sti_class/version'

Gem::Specification.new do |spec|
  spec.name          = 'store_base_sti_class'
  spec.version       = StoreBaseSTIClass::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.author        = 'AppFolio'
  spec.email         = 'opensource@appfolio.com'
  spec.description   = 'By default ActiveRecord stores the base class in polymorphic type columns when using single table inheritance, which can have performance implications. This gem adds a store_base_sti_class configuration option that controls whether ActiveRecord stores the base class or the actual class, defaulting to the original behavior for backward compatibility.'
  spec.summary       = 'Stores the actual class instead of the base class in polymorphic type columns for ActiveRecord STI.'
  spec.homepage      = 'https://github.com/appfolio/store_base_sti_class'
  spec.license       = 'MIT'
  spec.files         = Dir['**/*'].select { |f| f[%r{^(lib/|LICENSE.txt|.*gemspec)}] }
  spec.require_paths = ['lib']

  spec.required_ruby_version = Gem::Requirement.new('< 4.1')
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.add_dependency('activerecord', ['>= 7.2', '< 8.2'])
end
