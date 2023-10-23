# frozen_string_literal: true

require_relative 'lib/store_base_sti_class/version'

Gem::Specification.new do |spec|
  spec.name                  = 'store_base_sti_class'
  spec.version               = StoreBaseSTIClass::VERSION
  spec.platform              = Gem::Platform::RUBY
  spec.author                = 'AppFolio'
  spec.email                 = 'opensource@appfolio.com'
  spec.description           = <<~MSG
    ActiveRecord has always stored the base class in polymorphic _type columns when using STI. This can have non-trivial
    performance implications in certain cases. This gem adds the 'store_base_sti_class' configuration option which
    controls whether ActiveRecord will store the base class or the actual class. Defaults to true for backwards
    compatibility.'
  MSG
  spec.summary               = <<~MSG
    Modifies ActiveRecord 6.1.x - 7.1.x with the ability to store the actual class (instead of the base class) in
    polymorhic _type columns when using STI.
  MSG
  spec.homepage              = 'https://github.com/appfolio/store_base_sti_class'
  spec.license               = 'MIT'
  spec.files                 = Dir['**/*'].select { |f| f[%r{^(lib/|LICENSE.txt|.*gemspec)}] }
  spec.require_paths         = ['lib']
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.3')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.add_dependency('activerecord', ['>= 6.1', '< 7.2'])
end
