module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser
      class InformalDefinition < Definition
        def initialize kind, subject, phrases, text
          @kind = kind
          @subject = subject
          @phrases = phrases
          @text = text
        end

        def compile
          @context = CompilationContext.new(@vocabulary)
          case @kind
          when :each
            compile_object_description
          when :when
            compile_fact_type_description
          end
        end

        def apply_description concept_type
          concept_type.concept.informal_description =
            [ concept_type.concept.informal_description,
              @text
            ].compact*".\n"
        end

        def compile_object_description
          object_type = @context.object_type(@subject)
          raise "Cannot add informal description of undefined object #{@subject.inspect}" unless object_type
          apply_description object_type 
          false
        end

        def compile_fact_type_description
          @clause = Compiler::Clause.new(@phrases)  # Make the phrases into a clause
          @context.bind [@clause]                   # Bind player names in the claise
          fact_type = @clause.match_existing_fact_type @context
          apply_description fact_type if fact_type
          false
        end

      end
    end
  end
end

