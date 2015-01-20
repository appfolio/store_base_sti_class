require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

ActiveRecord::Base.configurations = {
  'unittest' => {
    :adapter  => 'sqlite3',
    :database => 'storebasestiname_unittest.sql',
  }
}

ActiveRecord::Base.establish_connection 'unittest'
