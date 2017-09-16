#
#       ActiveFacts CQL Parser.
#       Compiler classes relating to Transform Rules.
#
# Copyright (c) 2017 Factil Pty Ltd. Read the LICENSE file.
#
module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser

      class TransformRule < Definition
        attr_accessor :compound_transform_matching

        def initialize compound_transform_matching
          @compound_transform_matching = compound_transform_matching
        end

        def compile
          context = CompilationContext.new(@vocabulary)
          transform_matching = @compound_transform_matching.compile(context)
          @constellation.TransformRule(:new, :compound_transform_matching => transform_matching)
        end
      end

      def self.build_transform_target_refs context, targ_term_list, transform_rule
        vocabulary_identifier = context.vocabulary.identifying_role_values
        constellation = context.vocabulary.constellation

        targ_term_list.flatten!
        (0 ... targ_term_list.size).each do |idx|
          ref = targ_term_list[idx]
          if (target_ot = constellation.ObjectType[[vocabulary_identifier, ref.term]]).nil?
            raise "Target object '#{ref.term}' of transformation must be a valid object type"
          end
          constellation.TransformTargetRef(
            transform_rule, idx, :target_object_type => target_ot,
            :leading_adjective => ref.leading_adjective, :trailing_adjective => ref.trailing_adjective
          )
        end
      end

      class CompoundTransformMatching
        attr_accessor :targ_term_list, :transform_query, :transform_matchings

        def initialize targ_term_list, transform_query, transform_matchings
          @targ_term_list = targ_term_list
          @transform_query = transform_query
          @transform_matchings = transform_matchings
        end

        def compile(context)
          compound_rule = nil
          vocabulary_identifier = context.vocabulary.identifying_role_values
          constellation = context.vocabulary.constellation

          source_ot = nil
          source_query = nil
          if @transform_query.is_a?(ActiveFacts::CQL::Compiler::Reference)
            if (source_ot = constellation.ObjectType[[vocabulary_identifier, @transform_query.term]]).nil?
              raise "Invalid source object '#{@transform_query.term}' for '#{@targ_term.term}' transformation"
            end
          elsif @transform_query.is_a?(Array)
            query = Query.new(nil, @transform_query.flatten)
            query.constellation = constellation
            query.vocabulary = context.vocabulary
            if (source_query = query.compile).nil?
              raise "Invalid source query for '#{@targ_term.term}' transformation"
            end
          end

          compound_rule = constellation.CompoundTransformMatching(
            :new, :source_object_type => source_ot, :source_query => source_query
          )
          ActiveFacts::CQL::Compiler.build_transform_target_refs(context, @targ_term_list, compound_rule)

          @transform_matchings.each do |tr|
            trule = tr.compile(context)
            trule.compound_transform_matching = compound_rule
          end

          compound_rule
        end
      end

      class SimpleTransformMatching
        attr_accessor :targ_term_list, :transform_expr

        def initialize targ_term_list, transform_expr
          @targ_term_list = targ_term_list
          @transform_expr = transform_expr
        end

        def compile(context)
          vocabulary_identifier = context.vocabulary.identifying_role_values
          constellation = context.vocabulary.constellation

          expr = transform_expr ? transform_expr.compile(context) : nil
          simple_rule = constellation.SimpleTransformMatching(:new, :expression => expr)
          ActiveFacts::CQL::Compiler.build_transform_target_refs(context, @targ_term_list, simple_rule)

          simple_rule
        end
      end
    end
  end
end
