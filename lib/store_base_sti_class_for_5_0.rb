require 'active_record/associations/join_dependency/join_part'

if ActiveRecord::VERSION::STRING =~ /^5\.0/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
    end

    module Associations

      class JoinDependency # :nodoc:
        class JoinAssociation < JoinPart # :nodoc:
          def join_constraints(foreign_table, foreign_klass, node, join_type, tables, scope_chain, chain)
            joins         = []
            binds         = []
            tables        = tables.reverse

            scope_chain_index = 0
            scope_chain = scope_chain.reverse

            # The chain starts with the target table, but we want to end with it here (makes
            # more sense in this context), so we reverse
            chain.reverse_each do |reflection|
              table = tables.shift
              klass = reflection.klass

              join_keys   = reflection.join_keys(klass)
              key         = join_keys.key
              foreign_key = join_keys.foreign_key

              constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

              predicate_builder = PredicateBuilder.new(TableMetadata.new(klass, table))
              scope_chain_items = scope_chain[scope_chain_index].map do |item|
                if item.is_a?(Relation)
                  item
                else
                  ActiveRecord::Relation.create(klass, table, predicate_builder)
                    .instance_exec(node, &item)
                end
              end
              scope_chain_index += 1

              klass_scope =
                if klass.current_scope
                  klass.current_scope.clone
                else
                  relation = ActiveRecord::Relation.create(
                    klass,
                    table,
                    predicate_builder,
                  )
                  klass.send(:build_default_scope, relation)
                end
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
                value = ActiveRecord::Base.store_base_sti_class ? foreign_klass.base_class.name : foreign_klass.name
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

      class Preloader
        class Association

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

              scope.where!(klass.table_name => { reflection.type => ActiveRecord::Base.store_base_sti_class ? model.base_class.sti_name : model.sti_name })

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

              adjusted_foreign_type = if ActiveRecord::Base.store_base_sti_class
                options[:source_type]
              else
                ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)
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

        def next_chain_scope(scope, table, reflection, association_klass, foreign_table, next_reflection)
          join_keys = reflection.join_keys(association_klass)
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.type
            # BEGIN PATCH
            # original: 
            # value    = next_reflection.klass.base_class.name
            # bind_val = bind scope, table.table_name, reflection.type, value, tracker
            # scope    = scope.where(table[reflection.type].eq(bind_val))
            if ActiveRecord::Base.store_base_sti_class
              value = transform_value(next_reflection.klass.base_class.name)
              scope = scope.where(table.name => { reflection.type => value })
            else
              value = transform_value(next_reflection.klass.name)
              # TODO klass = next_reflection.klass
              # TODO scope = scope.where(table[reflection.type].in(([klass] + klass.descendants).map(&:name)))
            end
            # END PATCH
            
          end

          scope = scope.joins(join(foreign_table, constraint))
        end

        def last_chain_scope(scope, table, reflection, owner, association_klass)
          join_keys = reflection.join_keys(association_klass)
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          value = transform_value(owner[foreign_key])
          scope = scope.where(table.name => { key => value })

          if reflection.type
            # BEGIN PATCH
            # original: owner.class.base_class.name
            polymorphic_type = transform_value(ActiveRecord::Base.store_base_sti_class ? owner.class.base_class.name : owner.class.name)
            # END PATCH
            scope = scope.where(table.name => { reflection.type => polymorphic_type })
          end

          scope
        end
        
      end

    end

  end

end
