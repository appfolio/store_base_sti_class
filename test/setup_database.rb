# frozen_string_literal: true

require 'schema'

test_db_config = {
  adapter: 'mysql2',
  database: 'store_base_sti_class_test',
  username: 'root',
  host: '127.0.0.1',
  encoding: 'utf8mb4'
}

ActiveRecord::Tasks::DatabaseTasks.env = 'test'
ActiveRecord::Base.configurations = { 'test' => test_db_config }
ActiveRecord::Base.logger = Logger.new('test/test.log')

# Re-create test database
ActiveRecord::Tasks::DatabaseTasks.drop_current
ActiveRecord::Tasks::DatabaseTasks.create_current

Schema.up
