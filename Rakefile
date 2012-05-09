require 'rubygems'
require 'bundler'

require 'appraisal'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "store_base_sti_class"
  gem.homepage = "http://github.com/appfolio/store_base_sti_class"
  gem.license = "MIT"
  gem.summary = %Q{
    Modifies ActiveRecord 3.0.5+ with the ability to store the actual class (instead of the base class) in polymorhic _type columns when using STI
  }
  gem.description = %Q{
    ActiveRecord has always stored the base class in polymorphic _type columns when using STI. This can have non-trivial
    performance implications in certain cases. This gem adds 'store_base_sti_class' configuration options which controls
    whether ActiveRecord will store the base class or the actual class. Default to true for backwards compatibility.
  }
  gem.email = "andrew.mutz@appfolio.com"
  gem.authors = ["Andrew Mutz"]
  
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

