require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'minitest/autorun'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'store_base_sti_class'

require 'connection'

# silence verbose schema loading
original_stdout = $stdout
$stdout = StringIO.new
begin
  require "schema"
ensure
  $stdout = original_stdout
end

require 'models'

# the following is needed because ActiveRecord::TestCase uses ActiveRecord::SQLCounter, which is 
# not bundled as part of the gem
if Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new('3.2.0')
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
end

if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.1.0')
  require 'active_record/test_case'
else
  require 'active_support/test_case'
end

module StoreBaseSTIClass
  class TestCase < (Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('4.1.0') ? ActiveRecord::TestCase : ActiveSupport::TestCase)
    private

    if Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new('3.2.0')

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
        assert_queries(0, :ignore_none => true, &block)
      end

    end
  end
end
