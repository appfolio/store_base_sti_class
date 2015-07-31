require 'active_record'

if ActiveRecord::VERSION::STRING =~ /^3\.0/  
require 'active_record/associations'
require 'active_record/reflection'
require 'active_record/association_preload'
require 'active_record/associations/has_many_association'
require 'active_record/associations/has_one_association'
require 'active_record/associations/through_association_scope'
require 'active_record/associations/association_proxy'
require 'active_record/associations/belongs_to_polymorphic_association'

class ActiveRecord::Base
  
  # Determine whether to store the base class or the actual class in polymorhic type columns when using STI
  superclass_delegating_accessor :store_base_sti_class
  self.store_base_sti_class = true
  
  class << self
    
    def polymorphic_sti_name
      store_base_sti_class ? base_class.sti_name : sti_name
    end

    def in_or_equals_sti_names
      if store_base_sti_class
        "= #{quote_value(base_class.sti_name)}"
      else
        names = sti_names.map { |name| quote_value(name) }
        names.length > 1 ? "IN (#{names.join(',')})" : "= #{names.first}"
      end
    end

    def sti_names
      ([self] + descendants).map { |model| model.sti_name }
    end
    
  end
  
end

module ActiveRecord
  module Reflection
    class AssociationReflection < MacroReflection #:nodoc:

      def active_record_primary_key
        @active_record_primary_key ||= options[:primary_key] || active_record.primary_key
      end

    end
  end
end

module ActiveRecord
  module AssociationPreload
    module ClassMethods
  
      private
  
      def preload_through_records(records, reflection, through_association)
        # p 'preload_through_records'
        through_reflection = reflections[through_association]
        through_primary_key = through_reflection.primary_key_name

        through_records = []
        if reflection.options[:source_type]
          interface = reflection.source_reflection.options[:foreign_type]
          source_type = reflection.options[:source_type].to_s.constantize
          preload_options = { :conditions => "#{connection.quote_column_name interface} #{source_type.in_or_equals_sti_names}" }

          records.compact!
          records.first.class.preload_associations(records, through_association, preload_options)

          # Dont cache the association - we would only be caching a subset
          records.each do |record|
            proxy = record.send(through_association)

            if proxy.respond_to?(:target)
              through_records.concat Array.wrap(proxy.target)
              proxy.reset
            else # this is a has_one :through reflection
              through_records << proxy if proxy
            end
          end
        else
          options = {}
          options[:include] = reflection.options[:include] || reflection.options[:source] if reflection.options[:conditions] || reflection.options[:order]
          options[:order] = reflection.options[:order]
          options[:conditions] = reflection.options[:conditions]
          records.first.class.preload_associations(records, through_association, options)

          records.each do |record|
            through_records.concat Array.wrap(record.send(through_association))
          end
        end
        through_records
      end

      def find_associated_records(ids, reflection, preload_options)
        # p 'find_associated_records'
        options = reflection.options
        table_name = reflection.klass.quoted_table_name

        if interface = reflection.options[:as]
          conditions = "#{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_id"} #{in_or_equals_for_ids(ids)} and #{reflection.klass.quoted_table_name}.#{connection.quote_column_name "#{interface}_type"} #{self.in_or_equals_sti_names}"
        else
          foreign_key = reflection.primary_key_name
          conditions = "#{reflection.klass.quoted_table_name}.#{foreign_key} #{in_or_equals_for_ids(ids)}"
        end

        # p 'append_conditions'
        conditions << append_conditions(reflection, preload_options)

        find_options = {
          :select => preload_options[:select] || options[:select] || Arel::SqlLiteral.new("#{table_name}.*"),
          :include => preload_options[:include] || options[:include],
          :joins => options[:joins],
          :group => preload_options[:group] || options[:group],
          :order => preload_options[:order] || options[:order]
        }

        # p 'associated_records'
        associated_records(ids) do |some_ids|
          reflection.klass.scoped.apply_finder_options(find_options.merge(:conditions => [conditions, some_ids])).to_a
        end
      end

    end
  end
end

module ActiveRecord
  module Associations
    class HasManyAssociation < AssociationCollection

      protected

      def construct_sql
        # p 'construct_sql :has_many'
        
        case
          when @reflection.options[:finder_sql]
            @finder_sql = interpolate_and_sanitize_sql(@reflection.options[:finder_sql])

          when @reflection.options[:as]
            @finder_sql =
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_id = #{owner_quoted_id} AND " +
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_type #{@owner.class.in_or_equals_sti_names}"
            @finder_sql << " AND (#{conditions})" if conditions

          else
            @finder_sql = "#{@reflection.quoted_table_name}.#{@reflection.primary_key_name} = #{owner_quoted_id}"
            @finder_sql << " AND (#{conditions})" if conditions
        end

        construct_counter_sql
      end
      
    end
  end
end

module ActiveRecord
  module Associations
    class HasOneAssociation < AssociationProxy

      protected

      def construct_sql
        # p 'construct_sql :has_one'

        case
          when @reflection.options[:as]
            @finder_sql =
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_id = #{owner_quoted_id} AND " +
              "#{@reflection.quoted_table_name}.#{@reflection.options[:as]}_type #{@owner.class.in_or_equals_sti_names}"
          else
            @finder_sql = "#{@reflection.quoted_table_name}.#{@reflection.primary_key_name} = #{owner_quoted_id}"
        end
        @finder_sql << " AND (#{conditions})" if conditions
      end
      
    end
  end
end

module ActiveRecord
  module Associations
    module ThroughAssociationScope

      protected

      def construct_quoted_owner_attributes(reflection)
        # p 'construct_quoted_owner_attributes'

        if as = reflection.options[:as]
          { 
            "#{as}_id" => owner_quoted_id,
            "#{as}_type" => @owner.class.quote_value(@owner.class.polymorphic_sti_name)
          }
        elsif reflection.macro == :belongs_to
          { reflection.klass.primary_key => @owner.class.quote_value(@owner[reflection.primary_key_name]) }
        else
          { reflection.primary_key_name => owner_quoted_id }
        end
      end

      def construct_joins(custom_joins = nil)
        # p 'construct_joins'
        
        polymorphic_join = nil
        if @reflection.source_reflection.macro == :belongs_to
          reflection_primary_key = @reflection.klass.primary_key
          source_primary_key     = @reflection.source_reflection.primary_key_name
          if @reflection.options[:source_type]
            source_type = @reflection.options[:source_type].to_s.constantize
            polymorphic_join = "AND %s.%s #{source_type.in_or_equals_sti_names}" % [
              @reflection.through_reflection.quoted_table_name, 
              "#{@reflection.source_reflection.options[:foreign_type]}"
            ]
          end
        else
          reflection_primary_key = @reflection.source_reflection.primary_key_name
          source_primary_key     = @reflection.through_reflection.klass.primary_key
          if @reflection.source_reflection.options[:as]
            polymorphic_join = "AND %s.%s #{@reflection.through_reflection.klass.in_or_equals_sti_names}" % [
              @reflection.quoted_table_name, 
              "#{@reflection.source_reflection.options[:as]}_type"
            ]
          end
        end

        "INNER JOIN %s ON %s.%s = %s.%s %s #{@reflection.options[:joins]} #{custom_joins}" % [
          @reflection.through_reflection.quoted_table_name,
          @reflection.quoted_table_name, reflection_primary_key,
          @reflection.through_reflection.quoted_table_name, source_primary_key,
          polymorphic_join
        ]
      end
      
      def construct_owner_attributes(reflection)
        # p 'construct_owner_attributes'
        
        if as = reflection.options[:as]
          { "#{as}_id" => @owner.id,
            "#{as}_type" => @owner.class.polymorphic_sti_name }
        else
          { reflection.primary_key_name => @owner.id }
        end
      end
      
    end
  end
end

module ActiveRecord
  module Associations
    class AssociationProxy

      protected

      def set_belongs_to_association_for(record)
        # p 'set_belongs_to_association_for'

        if @reflection.options[:as]
          record["#{@reflection.options[:as]}_id"]   = @owner.id unless @owner.new_record?
          record["#{@reflection.options[:as]}_type"] = @owner.class.polymorphic_sti_name
        else
          unless @owner.new_record?
            primary_key = @reflection.options[:primary_key] || :id
            record[@reflection.primary_key_name] = @owner.send(primary_key)
          end
        end
      end
      
    end
  end
end

module ActiveRecord
  module Associations
    class BelongsToPolymorphicAssociation < AssociationProxy
      
      def replace(record)
        # p 'replace'
        
        if record.nil?
          @target = @owner[@reflection.primary_key_name] = @owner[@reflection.options[:foreign_type]] = nil
        else
          @target = (AssociationProxy === record ? record.target : record)

          @owner[@reflection.primary_key_name] = record_id(record)
          @owner[@reflection.options[:foreign_type]] = record.class.polymorphic_sti_name

          @updated = true
        end

        set_inverse_instance(record, @owner)
        loaded
        record
      end
      
    end
  end
end

module ActiveRecord
  module Associations
    module ThroughAssociationScope

      protected

      def construct_quoted_owner_attributes(reflection)
        # p 'construct_quoted_owner_attributes'
        if as = reflection.options[:as]
          { 
            "#{as}_id" => owner_quoted_id,
            "#{as}_type" => @owner.class.quote_value(@owner.class.polymorphic_sti_name)
          }
        elsif reflection.macro == :belongs_to
          { reflection.klass.primary_key => @owner.class.quote_value(@owner[reflection.primary_key_name]) }
        else
          { reflection.primary_key_name => owner_quoted_id }
        end
      end

      def construct_owner_attributes(reflection)
        # p 'construct_owner_attributes'
        if as = reflection.options[:as]
          { "#{as}_id" => @owner.id,
            "#{as}_type" => @owner.class.polymorphic_sti_name }
        else
          { reflection.primary_key_name => @owner.id }
        end
      end

      def construct_join_attributes(associate)
        # p 'construct_join_attributes'
        # TODO: revisit this to allow it for deletion, supposing dependent option is supported
        raise ActiveRecord::HasManyThroughCantAssociateThroughHasOneOrManyReflection.new(@owner, @reflection) if [:has_one, :has_many].include?(@reflection.source_reflection.macro)

        join_attributes = construct_owner_attributes(@reflection.through_reflection).merge(@reflection.source_reflection.primary_key_name => associate.id)

        if @reflection.options[:source_type]
          join_attributes.merge!(@reflection.source_reflection.options[:foreign_type] => associate.class.polymorphic_sti_name)
        end

        if @reflection.through_reflection.options[:conditions].is_a?(Hash)
          join_attributes.merge!(@reflection.through_reflection.options[:conditions])
        end

        join_attributes
      end

    end
  end
end

module ActiveRecord
  module Associations
    module ClassMethods
      class JoinDependency # :nodoc:
        class JoinAssociation < JoinBase # :nodoc:
  
          def association_join
            # p 'association_join'
            
            return @join if @join

            aliased_table = Arel::Table.new(table_name, :as      => @aliased_table_name,
                                                        :engine  => arel_engine,
                                                        :columns => klass.columns)

            parent_table = Arel::Table.new(parent.table_name, :as      => parent.aliased_table_name,
                                                              :engine  => arel_engine,
                                                              :columns => parent.active_record.columns)

            @join = case reflection.macro
            when :has_and_belongs_to_many
              join_table = Arel::Table.new(options[:join_table], :as => aliased_join_table_name, :engine => arel_engine)
              fk = options[:foreign_key] || reflection.active_record.to_s.foreign_key
              klass_fk = options[:association_foreign_key] || klass.to_s.foreign_key

              [
                join_table[fk].eq(parent_table[reflection.active_record.primary_key]),
                aliased_table[klass.primary_key].eq(join_table[klass_fk])
              ]
            when :has_many, :has_one
              if reflection.options[:through]
                join_table = Arel::Table.new(through_reflection.klass.table_name, :as => aliased_join_table_name, :engine => arel_engine)
                jt_as_extra = jt_source_extra = jt_sti_extra = nil
                first_key = second_key = nil

                if through_reflection.macro == :belongs_to
                  jt_primary_key = through_reflection.primary_key_name
                  jt_foreign_key = through_reflection.association_primary_key
                else
                  jt_primary_key = through_reflection.active_record_primary_key
                  jt_foreign_key = through_reflection.primary_key_name

                  if through_reflection.options[:as] # has_many :through against a polymorphic join
                    jt_as_extra = join_table[through_reflection.options[:as].to_s + '_type'].in(parent.active_record.sti_names)
                  end
                end

                case source_reflection.macro
                when :has_many
                  if source_reflection.options[:as]
                    first_key   = "#{source_reflection.options[:as]}_id"
                    second_key  = options[:foreign_key] || primary_key
                  else
                    first_key   = through_reflection.klass.base_class.to_s.foreign_key
                    second_key  = options[:foreign_key] || primary_key
                  end

                  unless through_reflection.klass.descends_from_active_record?
                    # there is no test for this condition
                    jt_sti_extra = join_table[through_reflection.active_record.inheritance_column].eq(through_reflection.klass.sti_name)
                  end
                when :belongs_to
                  first_key = primary_key
                  if reflection.options[:source_type]
                    source_type = reflection.options[:source_type].to_s.constantize
                    second_key = source_reflection.association_foreign_key
                    jt_source_extra = join_table[reflection.source_reflection.options[:foreign_type]].in(source_type.sti_names)
                  else
                    second_key = source_reflection.primary_key_name
                  end
                end

                [
                  [parent_table[jt_primary_key].eq(join_table[jt_foreign_key]), jt_as_extra, jt_source_extra, jt_sti_extra].reject{|x| x.blank? },
                  aliased_table[first_key].eq(join_table[second_key])
                ]
              elsif reflection.options[:as]
                id_rel = aliased_table["#{reflection.options[:as]}_id"].eq(parent_table[parent.primary_key])
                type_rel = aliased_table["#{reflection.options[:as]}_type"].in(parent.active_record.sti_names)
                [id_rel, type_rel]
              else
                foreign_key = options[:foreign_key] || reflection.active_record.name.foreign_key
                [aliased_table[foreign_key].eq(parent_table[reflection.options[:primary_key] || parent.primary_key])]
              end
            when :belongs_to
              [aliased_table[options[:primary_key] || reflection.klass.primary_key].eq(parent_table[options[:foreign_key] || reflection.primary_key_name])]
            end

            unless klass.descends_from_active_record?
              sti_column = aliased_table[klass.inheritance_column]
              sti_condition = sti_column.eq(klass.sti_name)
              klass.descendants.each {|subclass| sti_condition = sti_condition.or(sti_column.eq(subclass.sti_name)) }

              @join << sti_condition
            end

            [through_reflection, reflection].each do |ref|
              if ref && ref.options[:conditions]
                @join << process_conditions(ref.options[:conditions], aliased_table_name)
              end
            end

            @join
          end
          
        end
      end
    end
  end
end

end
