RAILS_VERSIONS = %w[
  4.2.11
  5.0.7
  5.1.6
  5.2.2
  6.0.0
].freeze

RAILS_VERSIONS.each do |version|
  appraise "rails_#{version}" do
    gem 'activerecord', version
    gem 'sqlite3', version == '6.0.0' ? '~> 1.4.0' : '~> 1.3.0'
  end
end
