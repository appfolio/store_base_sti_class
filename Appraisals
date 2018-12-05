RAILS_VERSIONS = %w[
  4.0.13
  4.1.16
  4.2.10
  5.0.7
  5.1.6
  5.2.0
].freeze

RAILS_VERSIONS.each do |version|
  appraise "rails_#{version}" do
    gem 'activerecord', version
  end
end
