require 'active_record'

if ActiveRecord::VERSION::STRING =~ /^4\.0/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
    end

    module Associations
      class Association

        def creation_attributes
          attributes = {}

          if (reflection.macro == :has_one || reflection.macro == :has_many) && !options[:through]
            attributes[reflection.foreign_key] = owner[reflection.active_record_primary_key]

            if reflection.options[:as]
              # START PATCH
              # original:
              # attributes[reflection.type] = owner.class.base_class.name

              attributes[reflection.type] = ActiveRecord::Base.store_base_sti_class ? owner.class.base_class.name : owner.class.name

              # END PATCH
            end
          end

          attributes
        end

      end

      class JoinDependency # :nodoc:
        class JoinAssociation < JoinPart # :nodoc:

          def join_to(manager)
            tables        = @tables.dup
            foreign_table = parent_table
            foreign_klass = parent.base_klass

            # The chain starts with the target table, but we want to end with it here (makes
            # more sense in this context), so we reverse
            chain.reverse.each_with_index do |reflection, i|
              table = tables.shift

              case reflection.source_macro
              when :belongs_to
                key         = reflection.association_primary_key
                foreign_key = reflection.foreign_key
              when :has_and_belongs_to_many
                # Join the join table first...
                manager.from(join(
                  table,
                  table[reflection.foreign_key].
                    eq(foreign_table[reflection.active_record_primary_key])
                ))

                foreign_table, table = table, tables.shift

                key         = reflection.association_primary_key
                foreign_key = reflection.association_foreign_key
              else
                key         = reflection.foreign_key
                foreign_key = reflection.active_record_primary_key
              end

              constraint = build_constraint(reflection, table, key, foreign_table, foreign_key)

              scope_chain_items = scope_chain[i]

              if reflection.type
                # START PATCH
                # original:
                # scope_chain_items += [
                #   ActiveRecord::Relation.new(reflection.klass, table)
                #     .where(reflection.type => foreign_klass.base_class.name)
                # ]

                if ActiveRecord::Base.store_base_sti_class
                  scope_chain_items += [
                    ActiveRecord::Relation.new(reflection.klass, table)
                      .where(reflection.type => foreign_klass.base_class.name)
                  ]
                else
                  scope_chain_items += [
                    ActiveRecord::Relation.new(reflection.klass, table)
                      .where(reflection.type => ([foreign_klass] + foreign_klass.descendants).map(&:name))
                  ]
                end

                # END PATCH
              end

              scope_chain_items += [reflection.klass.send(:build_default_scope)].compact

              scope_chain_items.each do |item|
                unless item.is_a?(Relation)
                  item = ActiveRecord::Relation.new(reflection.klass, table).instance_exec(self, &item)
                end

                constraint = constraint.and(item.arel.constraints) unless item.arel.constraints.empty?
              end

              manager.from(join(table, constraint))

              # The current table in this iteration becomes the foreign table in the next
              foreign_table, foreign_klass = table, reflection.klass
            end

            manager
          end
        end
      end


      class BelongsToPolymorphicAssociation < BelongsToAssociation #:nodoc:

        private

          def replace_keys(record)
            super

            # START PATCH
            # original: owner[reflection.foreign_type] = record && record.class.base_class.name

            unless ActiveRecord::Base.store_base_sti_class
              owner[reflection.foreign_type] = record && record.class.sti_name
            else
              owner[reflection.foreign_type] = record && record.class.base_class.name
            end

            #END PATCH
          end
      end
    end

    module Associations
      class Preloader
        class Association
          private

            def build_scope
              scope = klass.unscoped
              scope.default_scoped = true

              values         = reflection_scope.values
              preload_values = preload_scope.values

              scope.where_values      = Array(values[:where])      + Array(preload_values[:where])
              scope.references_values = Array(values[:references]) + Array(preload_values[:references])

              scope.select   preload_values[:select] || values[:select] || table[Arel.star]
              scope.includes! preload_values[:includes] || values[:includes]

              if options[:as]
                scope.where!(klass.table_name => {

                  #START PATCH
                  #original: reflection.type => model.base_class.sti_name

                  reflection.type => ActiveRecord::Base.store_base_sti_class ? model.base_class.sti_name : model.sti_name

                  #END PATCH
                })
              end

              scope
            end
        end

        module ThroughAssociation
          def through_scope
            through_scope = through_reflection.klass.unscoped

            if options[:source_type]
              #START PATCH
              #original: through_scope.where! reflection.foreign_type => options[:source_type]

              through_scope.where! reflection.foreign_type => ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)

              #END PATCH
            else
              unless reflection_scope.where_values.empty?
                through_scope.includes_values = Array(reflection_scope.values[:includes] || options[:source])
                through_scope.where_values    = reflection_scope.values[:where]
              end

              through_scope.references! reflection_scope.values[:references]
              through_scope.order! reflection_scope.values[:order] if through_scope.eager_loading?
            end

            through_scope
          end
        end
      end

      class AssociationScope
        def add_constraints(scope)
          tables = construct_tables

          chain.each_with_index do |reflection, i|
            table, foreign_table = tables.shift, tables.first

            if reflection.source_macro == :has_and_belongs_to_many
              join_table = tables.shift

              scope = scope.joins(join(
                join_table,
                table[reflection.association_primary_key].
                  eq(join_table[reflection.association_foreign_key])
              ))

              table, foreign_table = join_table, tables.first
            end

            if reflection.source_macro == :belongs_to
              if reflection.options[:polymorphic]
                key = reflection.association_primary_key(self.klass)
              else
                key = reflection.association_primary_key
              end

              foreign_key = reflection.foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end

            if reflection == chain.last
              bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key]
              scope    = scope.where(table[key].eq(bind_val))

              if reflection.type
                # START PATCH
                # original: value = owner.class.base_class.name

                unless ActiveRecord::Base.store_base_sti_class
                  value = owner.class.name
                else
                  value = owner.class.base_class.name
                end

                # END PATCH
                bind_val = bind scope, table.table_name, reflection.type.to_s, value
                scope    = scope.where(table[reflection.type].eq(bind_val))
              end
            else
              constraint = table[key].eq(foreign_table[foreign_key])

              if reflection.type
                # START PATCH
                # original: type = chain[i + 1].klass.base_class.name
                #           constraint = constraint.and(table[reflection.type].eq(type))

                if ActiveRecord::Base.store_base_sti_class
                  type = chain[i + 1].klass.base_class.name
                  constraint = constraint.and(table[reflection.type].eq(type))
                else
                  klass = chain[i + 1].klass
                  constraint = constraint.and(table[reflection.type].in(([klass] + klass.descendants).map(&:name)))
                end

                # END PATCH
              end

              scope = scope.joins(join(foreign_table, constraint))
            end

            is_first_chain = i == 0
            klass = is_first_chain ? self.klass : reflection.klass

            # Exclude the scope of the association itself, because that
            # was already merged in the #scope method.
            scope_chain[i].each do |scope_chain_item|
              item  = eval_scope(klass, scope_chain_item)

              if scope_chain_item == self.reflection.scope
                scope.merge! item.except(:where, :includes)
              end

              if is_first_chain
                scope.includes! item.includes_values
              end

              scope.where_values += item.where_values
              scope.order_values |= item.order_values
            end
          end

          scope
        end

      end
    end

    module Reflection
      class ThroughReflection < AssociationReflection

        def scope_chain
          @scope_chain ||= begin
            scope_chain = source_reflection.scope_chain.map(&:dup)

            # Add to it the scope from this reflection (if any)
            scope_chain.first << scope if scope

            through_scope_chain = through_reflection.scope_chain.map(&:dup)

            if options[:source_type]
              # START PATCH
              # original:
              # through_scope_chain.first <<
              #   through_reflection.klass.where(foreign_type => options[:source_type])

              unless ActiveRecord::Base.store_base_sti_class
                through_scope_chain.first <<
                  through_reflection.klass.where(foreign_type => ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s))
              else
                through_scope_chain.first <<
                  through_reflection.klass.where(foreign_type => options[:source_type])
              end

              # END PATCH
            end

            # Recursively fill out the rest of the array from the through reflection
            scope_chain + through_scope_chain
          end
        end
      end
    end

  end

end
