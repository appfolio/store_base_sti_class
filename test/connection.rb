require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => 'storebasestiname_unittest.sql',
)
