module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser

      # In a declaration, a Binding has one or more NounPhrase's.
      # A Binding is for a single ObjectType, normally related to just one Role,
      # and the noun phrases that refer to it are normally the object_type name
      # with the same adjectives (modulo loose binding),
      # or a role name or subscript reference.
      #
      # In some situations a Binding will have some NounPhrases with the same adjectives,
      # and one or more NounPhrases with no adjectives - this is called "loose binding".
      class Binding
        attr_reader :player             # The ObjectType (object type)
        attr_reader :nps               # an array of the NounPhrases
        attr_accessor :role_name
        attr_accessor :rebound_to       # Loose binding may set this to another binding
        attr_reader :variable
        attr_accessor :instance         # When binding fact instances, the instance goes here

        def initialize player, role_name = nil
          @player = player
          @role_name = role_name
          @nps = []
        end

        def inspect
          "#{@player.name}#{@role_name and @role_name.is_a?(Integer) ? " (#{@role_name})" : " (as #{@role_name})"}"
        end

        def key
          "#{@player.name}#{@role_name && " (as #{@role_name})"}"
        end

        def <=>(other)
          key <=> other.key
        end

        def variable= v
          @variable = v   # A place for a breakpoint :)
        end

        def add_np np
          @nps << np
          np
        end

        def delete_np np
          @nps.delete np
        end
      end

      class CompilationContext
        attr_accessor :vocabulary
        attr_accessor :allowed_forward_terms
        attr_accessor :left_contraction_allowed
        attr_accessor :left_contractable_clause
        attr_accessor :left_contraction_conjunction
        attr_reader :bindings             # The Bindings in this declaration
        attr_reader :player_by_role_name

        def initialize vocabulary
          @vocabulary = vocabulary
          @vocabulary_identifier = @vocabulary.identifying_role_values
          @allowed_forward_terms = []
          @bindings = {}
          @player_by_role_name = {}
          @left_contraction_allowed = false
        end

        # Look up this object_type by its name
        def object_type(name)
          constellation = @vocabulary.constellation
          player = constellation.ObjectType[[@vocabulary_identifier, name]]

          # Bind to an existing role which has a role name (that's why we bind those first)
          player ||= @player_by_role_name[name]

          if !player && @allowed_forward_terms.include?(name)
            @vocabulary.valid_entity_type_name(name)  # No need for the result here, just no exceptional condition
            player = constellation.EntityType(@vocabulary, name, :concept => :new)
          end

          player
        end

        # Pass in an array of clauses or NounPhrases for player identification and binding (creating the Bindings)
        # It's necessary to identify all players that define a role name first,
        # so those names exist in the context for where they're used.
        def bind *clauses
          cl = clauses.flatten
          cl.each { |clause| clause.identify_players_with_role_name(self) }
          cl.each { |clause| clause.identify_other_players(self) }
          cl.each { |clause| clause.bind(self) }
        end
      end

      class Definition
        attr_accessor :constellation, :vocabulary, :tree
        def compile
          raise "#{self.class} should implement the compile method"
        end

        def to_s
          @vocabulary ? "#{vocabulary.to_s}::" : ''
        end

        def source
          @tree.text_value
        end

        def assert_literal_value(val)
          if val.is_a?(String)
            @constellation.Value(eval(val), true, nil)
          elsif val
            @constellation.Value(val.to_s, false , nil)
          else
            nil
          end
        end
      end

      class Schema < Definition
        def initialize name, is_transform, version_number
          @name = name
          @is_transform = is_transform
          @version_number = version_number
        end

        def compile
          if @constellation.Vocabulary.size > 0
            @constellation.Topic @name
          else
            @constellation.Vocabulary(@name, is_transform: @is_transform, version_number: @version_number)
          end
        end

        def to_s
          @name
        end
      end

      class Import < Definition
        def initialize parser, name, import_role, version_pattern, alias_hash
          @parser = parser
          @name = name
          @import_role = import_role
          @version_pattern = version_pattern
          @alias_hash = alias_hash
        end

        def to_s
          "#{@vocabulary.to_s} imports #{@alias_hash.map{|k,v| "#{k} as #{v}" }*', '};"
        end

        def compile
          @parser.compile_import(@name, @import_role, @alias_hash)
        end
      end

      class ObjectType < Definition
        attr_reader :name

        def initialize name
          @name = name
        end

        def to_s
          "#{super}#{@name}"
        end
      end

    end
  end
end
