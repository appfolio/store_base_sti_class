# frozen_string_literal: true

require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

if ENV['WITH_COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    add_filter %r{\A/test}
  end
end

require 'store_base_sti_class'
require 'minitest/autorun'
require 'minitest/reporters'
require 'setup_database'
require 'models'

Minitest::Test.make_my_diffs_pretty!
Minitest::Reporters.use! unless ENV['RM_INFO']

# the following is needed because ActiveRecord::TestCase uses ActiveRecord::SQLCounter, which is
# not bundled as part of the gem
module ActiveRecord
  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all

      def clear_log;
        self.log = []; self.log_all = [];
      end
    end

    self.clear_log

    self.ignored_sql   = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/, /^BEGIN/, /^COMMIT/]

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL, or better yet, use a different notification for the queries
    # instead examining the SQL content.
    oracle_ignored     = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im]
    mysql_ignored      = [/^SHOW TABLES/i, /^SHOW FULL FIELDS/]
    postgresql_ignored = [/^\s*select\b.*\bfrom\b.*pg_namespace\b/im, /^\s*select\b.*\battname\b.*\bfrom\b.*\bpg_attribute\b/im, /^SHOW search_path/i]
    sqlite3_ignored    = [/^\s*SELECT name\b.*\bFROM sqlite_master/im]

    [oracle_ignored, mysql_ignored, postgresql_ignored, sqlite3_ignored].each do |db_ignored_sql|
      ignored_sql.concat db_ignored_sql
    end

    attr_reader :ignore

    def initialize(ignore = Regexp.union(self.class.ignored_sql))
      @ignore = ignore
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if 'CACHE' == values[:name]

      self.class.log_all << sql
      self.class.log << sql unless ignore =~ sql
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end

require 'active_support/test_case'

module ActiveSupport
  class TestCase
    private

    def assert_queries(num = 1, options = {})
      ignore_none = options.fetch(:ignore_none) { num == :any }
      ActiveRecord::SQLCounter.clear_log
      yield
    ensure
      the_log = ignore_none ? ActiveRecord::SQLCounter.log_all : ActiveRecord::SQLCounter.log
      if num == :any
        assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
      else
        mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
        assert_equal num, the_log.size, mesg
      end
    end

    def assert_no_queries(&block)
      assert_queries(0, ignore_none: true, &block)
    end
  end
end
