require 'active_record'

if ActiveRecord::VERSION::STRING =~ /^3\.0/
  require 'store_base_sti_class_for_3_0'
elsif ActiveRecord::VERSION::STRING =~ /^3\.(1|2)/
  require 'store_base_sti_class_for_3_1_and_above'
elsif ActiveRecord::VERSION::STRING =~ /^4\.0/
  require 'store_base_sti_class_for_4_0'
elsif ActiveRecord::VERSION::STRING =~ /^4\.1/
  require 'store_base_sti_class_for_4_1'
elsif ActiveRecord::VERSION::STRING =~ /^4\.2/
  require 'store_base_sti_class_for_4_2'
end

module StoreBaseSTIClass
end
