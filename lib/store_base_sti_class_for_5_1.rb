require 'active_record/associations/join_dependency/join_part'

if ActiveRecord::VERSION::STRING =~ /^5\.1/
  module ActiveRecord

    class Base
      class_attribute :_store_sti_classes, instance_accessor: false
      def self.store_sti_classes
        _store_sti_classes
      end
      # Override the setter so we can validate the input
      def self.store_sti_classes=(new)
        raise ArgumentError, "store_sti_classes must be set to an array or :all but was #{new.inspect}" unless new == :all or new.is_a? Array
        new.map(&:constantize).each { |klass|
          if klass != klass.base_class
            raise ArgumentError, " You tried to set store_sti_classes to #{klass}, but store_sti_classes should only be set to an array of *base* classes for which you want to store the STI class (itself or any of its STI subclasses) in any _type columns. Did you mean '#{klass.base_class}'?"
          end
        } if new.is_a? Array
        self._store_sti_classes = new
      end
      self.store_sti_classes = []

      def self.store_sti_class?(klass)
        return true if store_sti_classes == :all
        klass = klass.is_a?(Class) ? klass : klass.constantize
        store_sti_classes.include? klass.base_class.name
      end

      # For backwards compatibility
      def self.store_base_sti_class=(new)
        if new == true
          self.store_sti_classes = []
        elsif new == false
          self.store_sti_classes = :all
        else
          raise ArgumentError, "store_base_sti_class can only be set to true or false but tried setting to #{new}"
        end
      end
    end

    module Associations
      class Association
        private

        def creation_attributes
          attributes = {}

          if (reflection.has_one? || reflection.collection?) && !options[:through]
            attributes[reflection.foreign_key] = owner[reflection.active_record_primary_key]

            if reflection.options[:as]
              # START PATCH
              # original:
              # attributes[reflection.type] = owner.class.base_class.name

              attributes[reflection.type] = ActiveRecord::Base.store_sti_class?(owner.class) ? owner.class.name : owner.class.base_class.name
              # END PATCH
            end
          end

          attributes
        end
      end

      class JoinDependency # :nodoc:
        class JoinAssociation < JoinPart # :nodoc:
          def join_constraints(foreign_table, foreign_klass, join_type, tables, chain)
            joins         = []
            binds         = []
            tables        = tables.reverse

            # The chain starts with the target table, but we want to end with it here (makes
            # more sense in this context), so we reverse
            chain.reverse_each do |reflection|
              table = tables.shift
              klass = reflection.klass

              join_keys   = reflection.join_keys
              key         = join_keys.key
              foreign_key = join_keys.foreign_key

              constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

              predicate_builder = PredicateBuilder.new(TableMetadata.new(klass, table))
              scope_chain_items = reflection.join_scopes(table, predicate_builder)
              klass_scope       = reflection.klass_join_scope(table, predicate_builder)

              scope_chain_items.concat [klass_scope].compact

              rel = scope_chain_items.inject(scope_chain_items.shift) do |left, right|
                left.merge right
              end

              if rel && !rel.arel.constraints.empty?
                binds += rel.bound_attributes
                constraint = constraint.and rel.arel.constraints
              end

              if reflection.type
                # START PATCH
                # original:
                # value = foreign_klass.base_class.name
                value = ActiveRecord::Base.store_sti_class?(foreign_klass) ? foreign_klass.name : foreign_klass.base_class.name
                # END PATCH
                column = klass.columns_hash[reflection.type.to_s]

                binds << Relation::QueryAttribute.new(column.name, value, klass.type_for_attribute(column.name))
                constraint = constraint.and klass.arel_attribute(reflection.type, table).eq(Arel::Nodes::BindParam.new)
              end

              joins << table.create_join(table, table.create_on(constraint), join_type)

              # The current table in this iteration becomes the foreign table in the next
              foreign_table, foreign_klass = table, klass
            end

            JoinInformation.new joins, binds
          end
        end
      end

      class BelongsToPolymorphicAssociation
        private

        def replace_keys(record)
          super

          # START PATCH
          # original:
          # owner[reflection.foreign_type] = record.class.base_class.name

          owner[reflection.foreign_type] = ActiveRecord::Base.store_sti_class?(record.class) ? record.class.name : record.class.base_class.name

          # END PATCH
        end
      end

      class Preloader
        class Association
          private

          def build_scope
            scope = klass.unscoped

            values = reflection_scope.values
            preload_values = preload_scope.values

            scope.where_clause = reflection_scope.where_clause + preload_scope.where_clause
            scope.references_values = Array(values[:references]) + Array(preload_values[:references])

            if preload_values[:select] || values[:select]
              scope._select!(preload_values[:select] || values[:select])
            end
            scope.includes! preload_values[:includes] || values[:includes]
            if preload_scope.joins_values.any?
              scope.joins!(preload_scope.joins_values)
            else
              scope.joins!(reflection_scope.joins_values)
            end

            if order_values = preload_values[:order] || values[:order]
              scope.order!(order_values)
            end

            if preload_values[:reordering] || values[:reordering]
              scope.reordering_value = true
            end

            if preload_values[:readonly] || values[:readonly]
              scope.readonly!
            end

            if options[:as]
              # START PATCH
              # original:
              # scope.where!(klass.table_name => { reflection.type => model.base_class.sti_name })

              scope.where!(klass.table_name => { reflection.type => ActiveRecord::Base.store_sti_class?(model) ? model.sti_name : model.base_class.sti_name })

              # END PATCH
            end

            scope.unscope_values = Array(values[:unscope]) + Array(preload_values[:unscope])
            klass.default_scoped.merge(scope)
          end
        end

        module ThroughAssociation
          private

          def through_scope
            scope = through_reflection.klass.unscoped

            if options[:source_type]
              # BEGIN PATCH
              # original: scope.where! reflection.foreign_type => options[:source_type]

              adjusted_foreign_type =
                if ActiveRecord::Base.store_sti_class?(options[:source_type])
                  ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)
                else
                  options[:source_type]
                end

              scope.where! reflection.foreign_type => adjusted_foreign_type

              # END PATCH
            else
              unless reflection_scope.where_clause.empty?
                scope.includes_values = Array(reflection_scope.values[:includes] || options[:source])
                scope.where_clause = reflection_scope.where_clause
              end

              scope.references! reflection_scope.values[:references]
              if scope.eager_loading? && order_values = reflection_scope.values[:order]
                scope = scope.order(order_values)
              end
            end

            scope
          end
        end
      end

      class AssociationScope

        def self.get_bind_values(owner, chain)
          binds = []
          last_reflection = chain.last

          binds << last_reflection.join_id_for(owner)
          if last_reflection.type
            # START PATCH
            # original: binds << owner.class.base_class.name
            binds << (ActiveRecord::Base.store_sti_class?(owner.class) ? owner.class.name : owner.class.base_class.name)
            # END PATCH
          end

          chain.each_cons(2).each do |reflection, next_reflection|
            if reflection.type
              # START PATCH
              # original: binds << next_reflection.klass.base_class.name
              binds << (ActiveRecord::Base.store_sti_class?(next_reflection.klass) ? next_reflection.klass.name : next_reflection.klass.base_class.name)
              # END PATCH
            end
          end
          binds
        end

        private

        def next_chain_scope(scope, table, reflection, foreign_table, next_reflection)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.type
            # BEGIN PATCH
            # original:
            # value = transform_value(next_reflection.klass.base_class.name)
            # scope = scope.where(table.name => { reflection.type => value })
            klass = next_reflection.klass
            if ActiveRecord::Base.store_sti_class?(klass)
              value = ([klass] + klass.descendants).map(&:name)
            else
              value = transform_value(klass.base_class.name)
            end
            scope = scope.where(table.name => { reflection.type => value })
            # END PATCH
          end

          scope = scope.joins(join(foreign_table, constraint))
        end

        def last_chain_scope(scope, table, reflection, owner)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          value = transform_value(owner[foreign_key])
          scope = scope.where(table.name => { key => value })

          if reflection.type
            # BEGIN PATCH
            # polymorphic_type = transform_value(owner.class.base_class.name)
            polymorphic_type = transform_value(ActiveRecord::Base.store_sti_class?(owner.class) ? owner.class.name : owner.class.base_class.name)
            # END PATCH
            scope = scope.where(table.name => { reflection.type => polymorphic_type })
          end

          scope
        end

      end

      module ThroughAssociation
        private

        def construct_join_attributes(*records)
          ensure_mutable

          if source_reflection.association_primary_key(reflection.klass) == reflection.klass.primary_key
            join_attributes = { source_reflection.name => records }
          else
            join_attributes = {
              source_reflection.foreign_key =>
                records.map { |record|
                  record.send(source_reflection.association_primary_key(reflection.klass))
                }
            }
          end

          if options[:source_type]

            # START PATCH
            # original:
            # join_attributes[source_reflection.foreign_type] =
            #  records.map { |record| record.class.base_class.name }

            join_attributes[source_reflection.foreign_type] =
              records.map { |record| ActiveRecord::Base.store_sti_class?(record.class) ? record.class.name : record.class.base_class.name }

            # END PATCH
          end

          if records.count == 1
            Hash[join_attributes.map { |k, v| [k, v.first] }]
          else
            join_attributes
          end
        end
      end

      class HasManyThroughAssociation
        private

        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            through_record = through_association.build(*options_for_through_record)
            through_record.send("#{source_reflection.name}=", record)

            # START PATCH
            # original:
            # if options[:source_type]
            #   through_record.send("#{source_reflection.foreign_type}=", options[:source_type])
            # end
            if options[:source_type] && !ActiveRecord::Base.store_sti_class?(options[:source_type])
              through_record.send("#{source_reflection.foreign_type}=", options[:source_type])
            end
            # END PATCH

            through_record
          end
        end
      end
    end

    module Reflection
      class PolymorphicReflection
        def source_type_info
          type = @previous_reflection.foreign_type
          source_type = @previous_reflection.options[:source_type]

          # START PATCH
          adjusted_source_type =
            if ActiveRecord::Base.store_sti_class?(source_type)
              ([source_type.constantize] + source_type.constantize.descendants).map(&:to_s)
            else
              source_type
            end
          # END PATCH

          lambda { |object| where(type => adjusted_source_type) }
        end
      end
    end
  end

end
