if ActiveRecord::VERSION::STRING =~ /^4\.1/
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

      class JoinDependency
        class JoinAssociation
          def join_constraints(foreign_table, foreign_klass, node, join_type, tables, scope_chain, chain)
            joins         = []
            tables        = tables.reverse

            scope_chain_index = 0
            scope_chain = scope_chain.reverse

            # The chain starts with the target table, but we want to end with it here (makes
            # more sense in this context), so we reverse
            chain.reverse_each do |reflection|
              table = tables.shift
              klass = reflection.klass

              case reflection.source_macro
              when :belongs_to
                key         = reflection.association_primary_key
                foreign_key = reflection.foreign_key
              else
                key         = reflection.foreign_key
                foreign_key = reflection.active_record_primary_key
              end

              constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

              scope_chain_items = scope_chain[scope_chain_index].map do |item|
                if item.is_a?(Relation)
                  item
                else
                  ActiveRecord::Relation.create(klass, table).instance_exec(node, &item)
                end
              end
              scope_chain_index += 1

              scope_chain_items.concat [klass.send(:build_default_scope, ActiveRecord::Relation.create(klass, table))].compact

              rel = scope_chain_items.inject(scope_chain_items.shift) do |left, right|
                left.merge right
              end

              if reflection.type
                # START PATCH
                # original:
                # constraint = constraint.and table[reflection.type].eq foreign_klass.base_class.name

                sti_class_name = ActiveRecord::Base.store_base_sti_class ? foreign_klass.base_class.name : foreign_klass.name
                constraint     = constraint.and table[reflection.type].eq sti_class_name

                # END PATCH
              end

              if rel && !rel.arel.constraints.empty?
                constraint = constraint.and rel.arel.constraints
              end

              joins << table.create_join(table, table.create_on(constraint), join_type)

              # The current table in this iteration becomes the foreign table in the next
              foreign_table, foreign_klass = table, klass
            end

            joins
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

          owner[reflection.foreign_type] = ActiveRecord::Base.store_base_sti_class ? record.class.base_class.name : record.class.name

          # END PATCH
        end
      end

      class Preloader
        class Association
          def build_scope
            scope = klass.unscoped

            values         = reflection_scope.values
            preload_values = preload_scope.values

            scope.where_values      = Array(values[:where])      + Array(preload_values[:where])
            scope.references_values = Array(values[:references]) + Array(preload_values[:references])

            select_method = scope.respond_to?(:select!) ? :select! : :_select!
            scope.send select_method, preload_values[:select] || values[:select] || table[Arel.star]
            scope.includes! preload_values[:includes] || values[:includes]

            if preload_values.key? :order
              scope.order! preload_values[:order]
            else
              if values.key? :order
                scope.order! values[:order]
              end
            end

            if options[:as]
              # START PATCH
              # original:
              # scope.where!(klass.table_name => { reflection.type => model.base_class.sti_name })

              scope.where!(klass.table_name => { reflection.type => ActiveRecord::Base.store_base_sti_class ? model.base_class.sti_name : model.sti_name })

              # END PATCH
            end

            scope.unscope_values = Array(values[:unscope])
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
              unless reflection_scope.where_values.empty?
                scope.includes_values = Array(reflection_scope.values[:includes] || options[:source])
                scope.where_values    = reflection_scope.values[:where]
              end

              scope.references! reflection_scope.values[:references]
              scope.order! reflection_scope.values[:order] if scope.eager_loading?
            end

            scope
          end
        end
      end

      class AssociationScope
        def add_constraints(scope, owner, assoc_klass, refl, tracker)
          chain = refl.chain
          scope_chain = refl.scope_chain

          tables = construct_tables(chain, assoc_klass, refl, tracker)

          chain.each_with_index do |reflection, i|
            table, foreign_table = tables.shift, tables.first

            if reflection.source_macro == :belongs_to
              if reflection.options[:polymorphic]
                key = reflection.association_primary_key(assoc_klass)
              else
                key = reflection.association_primary_key
              end

              foreign_key = reflection.foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end

            if reflection == chain.last
              bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key], tracker
              scope    = scope.where(table[key].eq(bind_val))

              if reflection.type
                # START PATCH
                # original: value = owner.class.base_class.name

                if ActiveRecord::Base.store_base_sti_class
                  value = owner.class.base_class.name
                else
                  value = owner.class.name
                end

                # END PATCH

                bind_val = bind scope, table.table_name, reflection.type.to_s, value, tracker
                scope    = scope.where(table[reflection.type].eq(bind_val))
              end
            else
              constraint = table[key].eq(foreign_table[foreign_key])

              if reflection.type
                # START PATCH
                # original: type = chain[i + 1].klass.base_class.name
                #           scope = scope.where(table[reflection.type].eq(bind_val))

                if ActiveRecord::Base.store_base_sti_class
                  type = chain[i + 1].klass.base_class.name
                  scope = scope.where(table[reflection.type].eq(type))
                else
                  klass = chain[i + 1].klass
                  scope = scope.where(table[reflection.type].in(([klass] + klass.descendants).map(&:name)))
                end

                # END PATCH
              end

              scope = scope.joins(join(foreign_table, constraint))
            end

            is_first_chain = i == 0
            klass = is_first_chain ? assoc_klass : reflection.klass

            # Exclude the scope of the association itself, because that
            # was already merged in the #scope method.
            scope_chain[i].each do |scope_chain_item|
              item  = eval_scope(klass, scope_chain_item, owner)

              if scope_chain_item == refl.scope
                scope.merge! item.except(:where, :includes, :bind)
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

      module ThroughAssociation
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
              records.map { |record| ActiveRecord::Base.store_base_sti_class ? record.class.base_class.name : record.class.name }

            # END PATCH
          end

          if records.count == 1
            Hash[join_attributes.map { |k, v| [k, v.first] }]
          else
            join_attributes
          end
        end

      end

    end

    module Reflection
      class ThroughReflection
        def scope_chain
          @scope_chain ||= begin
            scope_chain = source_reflection.scope_chain.map(&:dup)

            # Add to it the scope from this reflection (if any)
            scope_chain.first << scope if scope

            through_scope_chain = through_reflection.scope_chain.map(&:dup)

            if options[:source_type]
              type = foreign_type

              # START PATCH
              # original: source_type = options[:source_type]

              source_type = if ActiveRecord::Base.store_base_sti_class
                options[:source_type]
              else
                ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)
              end

              # END PATCH

              through_scope_chain.first << lambda { |object|
                where(type => source_type)
              }
            end

            # Recursively fill out the rest of the array from the through reflection
            scope_chain + through_scope_chain
          end
        end
      end

    end
  end

end
