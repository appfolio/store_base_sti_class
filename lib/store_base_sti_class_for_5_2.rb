require 'active_record/associations/join_dependency/join_part'

if ActiveRecord::VERSION::STRING =~ /^5\.2/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
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
          private

          def build_scope
            scope = klass.scope_for_association

            if reflection.type
              # START PATCH
              # original:
              # scope.where!(reflection.type => model.base_class.sti_name)

              scope.where!(reflection.type => ActiveRecord::Base.store_base_sti_class ? model.base_class.sti_name : model.sti_name)

              # END PATCH
            end

            scope.merge!(reflection_scope) if reflection.scope
            scope.merge!(preload_scope) if preload_scope
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

        private

        def next_chain_scope(scope, reflection, next_reflection)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          table = reflection.aliased_table
          foreign_table = next_reflection.aliased_table
          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.type
            # BEGIN PATCH
            # original:
            # value = transform_value(next_reflection.klass.base_class.name)
            # scope = scope.where(table.name => { reflection.type => value })
            if ActiveRecord::Base.store_base_sti_class
              value = transform_value(next_reflection.klass.base_class.name)
            else
              klass = next_reflection.klass
              value = ([klass] + klass.descendants).map(&:name)
            end
            scope = apply_scope(scope, table, reflection.type, value)
            # END PATCH
          end

          scope.joins!(join(foreign_table, constraint))
        end

        def last_chain_scope(scope, reflection, owner)
          join_keys = reflection.join_keys
          key = join_keys.key
          foreign_key = join_keys.foreign_key

          table = reflection.aliased_table
          value = transform_value(owner[foreign_key])
          scope = apply_scope(scope, table, key, value)

          if reflection.type
            # BEGIN PATCH
            # polymorphic_type = transform_value(owner.class.base_class.name)
            polymorphic_type = transform_value(ActiveRecord::Base.store_base_sti_class ? owner.class.base_class.name : owner.class.name)
            # END PATCH
            scope = apply_scope(scope, table, reflection.type, polymorphic_type)
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

      class HasManyThroughAssociation
        private

        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            through_record = through_association.build(*options_for_through_record)
            through_record.send("#{source_reflection.name}=", record)

            # START PATCH
            if ActiveRecord::Base.store_base_sti_class
              if options[:source_type]
                through_record.send("#{source_reflection.foreign_type}=", options[:source_type])
              end
            end
            # END PATCH

            through_record
          end
        end
      end
    end

    module Reflection
      class AbstractReflection
        def join_scope(table, foreign_klass)
          predicate_builder = predicate_builder(table)
          scope_chain_items = join_scopes(table, predicate_builder)
          klass_scope       = klass_join_scope(table, predicate_builder)

          if type
            # START PATCH
            # original:
            # klass_scope.where!(type => foreign_klass.base_class.sti_name)
            adjusted_foreign_klass =
              if ActiveRecord::Base.store_base_sti_class
                foreign_klass.base_class.sti_name
              else
                foreign_klass.sti_name
              end
            # END PATCH

            klass_scope.where!(type => adjusted_foreign_klass)
          end

          scope_chain_items.inject(klass_scope, &:merge!)
        end
      end

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
