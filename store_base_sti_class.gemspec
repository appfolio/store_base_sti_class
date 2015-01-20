# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'store_base_sti_class/version'

Gem::Specification.new do |s|
  s.name = "store_base_sti_class"
  s.version = StoreBaseSTIClass::VERSION

  s.require_paths = ["lib"]
  s.authors = ["Andrew Mutz"]
  s.description = "\n    ActiveRecord has always stored the base class in polymorphic _type columns when using STI. This can have non-trivial\n    performance implications in certain cases. This gem adds 'store_base_sti_class' configuration options which controls\n    whether ActiveRecord will store the base class or the actual class. Default to true for backwards compatibility.\n  "
  s.email = "andrew.mutz@appfolio.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = Dir['**/*'].reject{ |f| f[%r{^pkg/}] || f[%r{^test/}] }

  s.homepage = "http://github.com/appfolio/store_base_sti_class"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "Modifies ActiveRecord 3.0.5 - 4.0.1 with the ability to store the actual class (instead of the base class) in polymorhic _type columns when using STI"

  s.add_runtime_dependency(%q<activerecord>, [">= 3.0.5"])
  s.add_development_dependency(%q<minitest>, [">= 4.0"])
  s.add_development_dependency(%q<sqlite3>, [">= 0"])
  s.add_development_dependency(%q<appraisal>, [">= 0"])
  s.add_development_dependency(%q<bundler>, [">= 0"])
end
