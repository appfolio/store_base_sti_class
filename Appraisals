# frozen_string_literal: true

case RUBY_VERSION
when '3.1.3', '3.2.1', '3.3.0'
  appraise "ruby-#{RUBY_VERSION}_activerecord61" do
    source 'https://rubygems.org' do
      gem 'activerecord', '~> 6.1.0'
    end
  end

  appraise "ruby-#{RUBY_VERSION}_activerecord70" do
    source 'https://rubygems.org' do
      gem 'activerecord', '~> 7.0.0'
    end
  end

  appraise "ruby-#{RUBY_VERSION}_activerecord71" do
    source 'https://rubygems.org' do
      gem 'activerecord', '~> 7.1.0'
    end
  end
else
  raise "Unsupported Ruby version #{RUBY_VERSION}"
end
