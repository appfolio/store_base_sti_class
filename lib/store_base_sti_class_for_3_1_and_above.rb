require 'active_record'

if ActiveRecord::VERSION::STRING =~ /^3\.(1|2)/
  module ActiveRecord

    class Base
      class_attribute :store_base_sti_class
      self.store_base_sti_class = true
    end
    
    module Associations
      class Association
        
        def creation_attributes
          attributes = {}

          if reflection.macro.in?([:has_one, :has_many]) && !options[:through]
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
          def join_to(relation)

            tables        = @tables.dup
            foreign_table = parent_table
            foreign_klass = parent.active_record

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
                relation.from(join(
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

              conditions = self.conditions[i].dup
              
              # START PATCH
              # original:
              # conditions << { reflection.type => foreign_klass.base_class.name } if reflection.type
              
              if ActiveRecord::Base.store_base_sti_class
                conditions << { reflection.type => foreign_klass.base_class.name } if reflection.type
              else
                conditions << { reflection.type => ([foreign_klass] + foreign_klass.descendants).map(&:name) } if reflection.type
              end
              
              # END PATCH

              unless conditions.empty?
                constraint = constraint.and(sanitize(conditions, table))
              end

              relation.from(join(table, constraint))

              # The current table in this iteration becomes the foreign table in the next
              foreign_table, foreign_klass = table, reflection.klass
            end

            relation
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

            scope = klass.scoped

            scope = scope.where(process_conditions(options[:conditions]))
            scope = scope.where(process_conditions(preload_options[:conditions]))

            scope = scope.select(preload_options[:select] || options[:select] || table[Arel.star])
            scope = scope.includes(preload_options[:include] || options[:include])



            if options[:as]
              scope = scope.where(
                klass.table_name => {
                  #START PATCH
                  #original: reflection.type => model.base_class.sti_name
                  reflection.type => ActiveRecord::Base.store_base_sti_class ? model.base_class.sti_name : model.sti_name
                  #END PATCH
                  
                }
              )
            end

            scope
          end
        end
        
        module ThroughAssociation
          def through_options
            through_options = {}
            if options[:source_type]
              #START PATCH
              #original: through_options[:conditions] = { reflection.foreign_type => options[:source_type] }
              through_options[:conditions] = { reflection.foreign_type =>  ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s)  }
              #END PATCH
            else
              if options[:conditions]
                through_options[:include]    = options[:include] || options[:source]
                through_options[:conditions] = options[:conditions]
              end

              through_options[:order] = options[:order]
            end
            through_options
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
                # START PATCH
                # This line exists to support multiple versions of AR 3.1
                # original in 3.1.3: key         = reflection.association_primary_key
                
                key = (reflection.method(:association_primary_key).arity == 0) ? reflection.association_primary_key : reflection.association_primary_key(klass)
                # END PATCH
              else
                key = reflection.association_primary_key
              end

              foreign_key = reflection.foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end

            conditions = self.conditions[i]

            if reflection == chain.last
              scope = scope.where(table[key].eq(owner[foreign_key]))

              if reflection.type
                # START PATCH
                # original: scope = scope.where(table[reflection.type].eq(owner.class.base_class.name))
                
                unless ActiveRecord::Base.store_base_sti_class
                  scope = scope.where(table[reflection.type].eq(owner.class.name))
                else
                  scope = scope.where(table[reflection.type].eq(owner.class.base_class.name))
                end
                
                # END PATCH
              end

              conditions.each do |condition|
                if options[:through] && condition.is_a?(Hash)
                  condition = { table.name => condition }
                end

                scope = scope.where(interpolate(condition))
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

              unless conditions.empty?
                scope = scope.where(sanitize(conditions, table))
              end
            end
          end

          scope
        end
        
      end
    end
    module Reflection
      class ThroughReflection < AssociationReflection
    
        def conditions
          @conditions ||= begin
            conditions = source_reflection.conditions.map { |c| c.dup }

            # Add to it the conditions from this reflection if necessary.
            conditions.first << options[:conditions] if options[:conditions]

            through_conditions = through_reflection.conditions

            if options[:source_type]
              # START PATCH
              # original: through_conditions.first << { foreign_type => options[:source_type] }
              
              unless ActiveRecord::Base.store_base_sti_class
                through_conditions.first << { foreign_type => ([options[:source_type].constantize] + options[:source_type].constantize.descendants).map(&:to_s) }
              else
                through_conditions.first << { foreign_type => options[:source_type] }
              end
              
              # END PATCH
            end

            # Recursively fill out the rest of the array from the through reflection
            conditions += through_conditions

            # And return
            conditions
          end
        end
      end
    end    
    
  end

end
