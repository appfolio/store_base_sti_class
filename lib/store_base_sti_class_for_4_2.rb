if ActiveRecord::VERSION::STRING =~ /^4\.2/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
    end

    module Associations
      class Association

        def creation_attributes
          attributes = {}

          if (reflection.has_one? || reflection.collection?) && !options[:through]
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
        def self.get_bind_values(owner, chain)
          binds = []
          last_reflection = chain.last

          binds << last_reflection.join_id_for(owner)
          if last_reflection.type
            # START PATCH
            # original: binds << owner.class.base_class.name
            binds << (ActiveRecord::Base.store_base_sti_class ? owner.class.base_class.name : owner.class.name)
            # END PATCH
          end

          chain.each_cons(2).each do |reflection, next_reflection|
            if reflection.type
              # START PATCH
              # original: binds << next_reflection.klass.base_class.name
              binds << (ActiveRecord::Base.store_base_sti_class ? next_reflection.klass.base_class.name : next_reflection.klass.name)
              # END PATCH
            end
          end
          binds
        end
        class BindSubstitution
          def bind_value(scope, column, value, alias_tracker)
            substitute = alias_tracker.connection.substitute_at(column)
            scope.bind_values += [[column, @block.call(value)]]
            substitute
          end
        end
        def next_chain_scope(scope, table, reflection, tracker, assoc_klass, foreign_table, next_reflection)
          join_keys = reflection.join_keys(assoc_klass)
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
              value    = next_reflection.klass.base_class.name
              bind_val = bind scope, table.table_name, reflection.type, value, tracker
              scope    = scope.where(table[reflection.type].eq(bind_val))
            else
              value    = next_reflection.klass.name
              klass    = next_reflection.klass
              scope    = scope.where(table[reflection.type].in(([klass] + klass.descendants).map(&:name)))
            end
            # END PATCH
            
          end

          scope = scope.joins(join(foreign_table, constraint))
        end
        def last_chain_scope(scope, table, reflection, owner, tracker, assoc_klass)
          join_keys = reflection.join_keys(assoc_klass)
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          bind_val = bind scope, table.table_name, key.to_s, owner[foreign_key], tracker
          scope    = scope.where(table[key].eq(bind_val))

          if reflection.type
            # BEGIN PATCH
            # original: owner.class.base_class.name
            value    = ActiveRecord::Base.store_base_sti_class ? owner.class.base_class.name : owner.class.name
            # END PATCH
            bind_val = bind scope, table.table_name, reflection.type, value, tracker
            scope    = scope.where(table[reflection.type].eq(bind_val))
          else
            scope
          end
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
