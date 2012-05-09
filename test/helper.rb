require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'store_base_sti_class'

require 'connection'

# silence verbose schema loading
original_stdout = $stdout
$stdout = StringIO.new
begin
  require "schema.rb"
ensure
  $stdout = original_stdout
end

require 'models'

# the following is needed because ActiveRecord::TestCase uses ActiveRecord::SQLCounter, which is 
# not bundled as part of the gem
if ActiveRecord::VERSION::STRING =~ /^3\.2/
  module ActiveRecord
    class SQLCounter
      cattr_accessor :ignored_sql
      self.ignored_sql = [/^PRAGMA (?!(table_info))/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/, /^BEGIN/, /^COMMIT/]

      # FIXME: this needs to be refactored so specific database can add their own
      # ignored SQL.  This ignored SQL is for Oracle.
      ignored_sql.concat [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im]

      cattr_accessor :log
      self.log = []

      attr_reader :ignore

      def initialize(ignore = self.class.ignored_sql)
        @ignore   = ignore
      end

      def call(name, start, finish, message_id, values)
        sql = values[:sql]

        # FIXME: this seems bad. we should probably have a better way to indicate
        # the query was cached
        return if 'CACHE' == values[:name] || ignore.any? { |x| x =~ sql }
        self.class.log << sql
      end
    end

    ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
  end  
end

