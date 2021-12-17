require 'active_record'

if ActiveRecord::VERSION::STRING =~ /^5\.0/
  require 'store_base_sti_class_for_5_0'
elsif ActiveRecord::VERSION::STRING =~ /^5\.1/
  require 'store_base_sti_class_for_5_1'
elsif ActiveRecord::VERSION::STRING =~ /^5\.2/
  require 'store_base_sti_class_for_5_2'
elsif ActiveRecord::VERSION::STRING =~ /^6\.0/
  require 'store_base_sti_class_for_6_0'
elsif ActiveRecord::VERSION::STRING =~ /^6\.1/
  require 'store_base_sti_class_for_6_1'
elsif ActiveRecord::VERSION::STRING =~ /^7\.0/
  require 'store_base_sti_class_for_7_0'
end

module StoreBaseSTIClass
end
