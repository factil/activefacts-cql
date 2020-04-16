module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser
      class Definition
        # Make a Variable for every binding present in these clauses
        def build_variables(clauses_list)
          trace :query, "Building variables" do
            query = @constellation.Query(:new)
            all_bindings_in_clauses(clauses_list).
              each do |binding|
                var_name = (r = binding.nps.select{|r| r.is_a?(NounPhrase)}.first) ? r.var_name : nil
                trace :query, "Creating variable #{query.all_variable.size} for #{binding.inspect} with role_name #{var_name}"
                binding.variable = @constellation.Variable(
                  query, query.all_variable.size, :object_type => binding.player, role_name: var_name
                )
                if literal = binding.nps.detect{|r| r.literal}
                  if literal.kind_of?(ActiveFacts::CQL::Compiler::NounPhrase)
                    # REVISIT: Fix this crappy ad-hoc polymorphism hack. ActiveFacts::CQL::Compiler::Literal should look like NounPhrase
                    literal = literal.literal
                  end
                  unit = @constellation.Unit.detect{|k, v| [v.name, v.plural_name].include? literal.unit} if literal.unit
                  binding.variable.value = [literal.literal.to_s, literal.literal.is_a?(String), unit]
                end
              end
            query
          end
        end

        def build_all_steps(query, clauses_list)
          roles_by_binding = {}
          trace :query, "Building steps" do
            clauses_list.each do |clause|
              build_step(query, clause, roles_by_binding)
            end
          end
          roles_by_binding
        end

        def build_step query, clause, roles_by_binding = {}, parent_variable = nil
          return unless clause.nps.size > 0  # Empty clause... really?

          # A bare object type is a valid clause, but it contains no fact type hence no step
          if clause.fact_type
            step = @constellation.Step(
                query, query.all_step.size,
                :fact_type => clause.fact_type,
                :alternative_set => nil,
                :is_disallowed => clause.certainty == false,
                :is_optional => clause.certainty == nil
              )
          end

          trace :query, "Creating Plays for #{clause.inspect} with #{clause.nps.size} nps" do
            is_input = true
            clause.nps.each do |np|
              # These nps are the Compiler::NounPhrases, which have associated Metamodel::RoleRefs,
              # but we need to create Plays for those roles.
              # REVISIT: Plays may need to save residual_adjectives
              binding = np.binding
              role = (np && np.role) || (np.role_ref && np.role_ref.role)

              objectification_step = nil
              if np.nested_clauses
                np.nested_clauses.each do |nested_clause|
                  objectification_step = build_step(query, nested_clause, roles_by_binding)
                  if np.binding.player.is_a?(ActiveFacts::Metamodel::EntityType) and
                      np.binding.player.fact_type == nested_clause.fact_type
                    objectification_step.objectification_variable = binding.variable
                  end
                end
              end
              if clause.is_naked_object_type
                raise "#{self} lacks a proper objectification" if clause.nps[0].nested_clauses and !objectification_step
                return objectification_step
              end

              if binding.variable.object_type != role.object_type         # Type mismatch
                if binding.variable.object_type.common_supertype(role.object_type)
                  # REVISIT: there's an implicit subtyping step here, create it; then always raise the error here.
                  # I don't want to do this for now because the verbaliser will always verbalise all steps.
                  # raise "Disallowing implicit subtyping step from #{role.object_type.name} to #{binding.variable.object_type.name} in #{clause.fact_type.default_reading.inspect}"
                else
                  raise "A #{role.object_type.name} cannot satisfy #{binding.variable.object_type.name} in #{clause.fact_type.default_reading.inspect}"
                end
              end

              trace :query, "Creating Play for #{np.inspect}"
              play = @constellation.Play(:step => step, :role => role, :variable => binding.variable)
              play.is_input = is_input
              is_input = false

              roles_by_binding[binding] = [role, play]
            end
          end

          step
        end

        # Return the unique array of all bindings in these clauses, including in objectification steps
        def all_bindings_in_clauses clauses
          clauses.map do |clause|
            clause.nps.map do |np|
              raise "Noun phrase #{np.inspect} must have a binding" unless np.binding
              [np.binding] + (np.nested_clauses ? all_bindings_in_clauses(np.nested_clauses) : [])
            end
          end.
            flatten.
            uniq
        end
      end
    end
  end
end
