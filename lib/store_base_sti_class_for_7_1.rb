require 'active_record/associations/join_dependency/join_part'

if ActiveRecord::VERSION::STRING =~ /\A7\.1s/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
    end

    module Inheritance
      module ClassMethods
        def polymorphic_name
          ActiveRecord::Base.store_base_sti_class ? base_class.name : name
        end
      end
    end

    module Associations
      class Preloader
        class ThroughAssociation < Association
          private

          def through_scope
            scope = through_reflection.klass.unscoped
            options = reflection.options

            values = reflection_scope.values
            if annotations = values[:annotate]
              scope.annotate!(*annotations)
            end

            if options[:source_type]
              # BEGIN PATCH
              # original:
              # scope.where! reflection.foreign_type => options[:source_type]

              adjusted_foreign_type =
                if ActiveRecord::Base.store_base_sti_class
                  options[:source_type]
                else
                  ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)
                end

              scope.where! reflection.foreign_type => adjusted_foreign_type
              # END PATCH

            elsif !reflection_scope.where_clause.empty?
              scope.where_clause = reflection_scope.where_clause

              if includes = values[:includes]
                scope.includes!(source_reflection.name => includes)
              else
                scope.includes!(source_reflection.name)
              end

              if values[:references] && !values[:references].empty?
                scope.references_values |= values[:references]
              else
                scope.references!(source_reflection.table_name)
              end

              if joins = values[:joins]
                scope.joins!(source_reflection.name => joins)
              end

              if left_outer_joins = values[:left_outer_joins]
                scope.left_outer_joins!(source_reflection.name => left_outer_joins)
              end

              if scope.eager_loading? && order_values = values[:order]
                scope = scope.order(order_values)
              end
            end

            scope
          end
        end
      end

      class AssociationScope
        private

        def next_chain_scope(scope, reflection, next_reflection)
          primary_key = reflection.join_primary_key
          foreign_key = reflection.join_foreign_key

          table = reflection.aliased_table
          foreign_table = next_reflection.aliased_table
          constraint = table[primary_key].eq(foreign_table[foreign_key])

          if reflection.type
            # BEGIN PATCH
            # original:
            # value = transform_value(next_reflection.klass.polymorphic_name)
            # scope = apply_scope(scope, table, reflection.type, value)

            if ActiveRecord::Base.store_base_sti_class
              value = transform_value(next_reflection.klass.polymorphic_name)
            else
              klass = next_reflection.klass
              value = ([klass] + klass.descendants).map(&:name)
            end
            scope = apply_scope(scope, table, reflection.type, value)
            # END PATCH
          end

          scope.joins!(join(foreign_table, constraint))
        end

      end

      class HasManyThroughAssociation
        private

        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            attributes = through_scope_attributes
            attributes[source_reflection.name] = record

            # START PATCH
            if ActiveRecord::Base.store_base_sti_class
              attributes[source_reflection.foreign_type] = options[:source_type] if options[:source_type]
            end
            # END PATCH

            through_association.build(attributes)
          end
        end
      end
    end

    module Reflection
      class PolymorphicReflection
        def source_type_scope
          type = @previous_reflection.foreign_type
          source_type = @previous_reflection.options[:source_type]

          # START PATCH
          adjusted_source_type =
            if ActiveRecord::Base.store_base_sti_class
              source_type
            else
              ([source_type.constantize] + source_type.constantize.descendants).map(&:to_s)
            end
          # END PATCH

          lambda { |object| where(type => adjusted_source_type) }
        end
      end
    end
  end

end
