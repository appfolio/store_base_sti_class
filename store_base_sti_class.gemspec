# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'store_base_sti_class/version'

Gem::Specification.new do |s|
  s.name = 'store_base_sti_class'
  s.version = StoreBaseSTIClass::VERSION

  s.require_paths = ['lib']
  s.authors = ['AppFolio']
  s.description = "\n    ActiveRecord has always stored the base class in polymorphic _type columns when using STI. This can have non-trivial\n    performance implications in certain cases. This gem adds the 'store_base_sti_class' configuration option which controls\n    whether ActiveRecord will store the base class or the actual class. Defaults to true for backwards compatibility.\n  "
  s.email = 'engineering@appfolio.com'
  s.extra_rdoc_files = %w(
    LICENSE.txt
    README.md
  )
  s.files = Dir['**/*'].reject{ |f| f[%r{^pkg/}] || f[%r{^test/}] }

  s.homepage = 'http://github.com/appfolio/store_base_sti_class'
  s.licenses = ['MIT']
  s.rubygems_version = '2.2.2'
  s.summary = 'Modifies ActiveRecord 4.0.x - 5.1.x with the ability to store the actual class (instead of the base class) in polymorhic _type columns when using STI'

  s.add_runtime_dependency(%q<activerecord>, ['>= 4.0'])
  s.add_development_dependency(%q<minitest>, ['>= 4.0'])
  s.add_development_dependency(%q<sqlite3>, ['>= 0'])
  s.add_development_dependency(%q<appraisal>, ['>= 0'])
  s.add_development_dependency(%q<bundler>, ['>= 0'])
end
