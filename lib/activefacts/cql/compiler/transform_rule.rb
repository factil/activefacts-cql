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
      
      class CompoundTransformMatching
        attr_accessor :targ_term, :transform_query, :transform_matchings
        
        def initialize targ_term, transform_query, transform_matchings
          @targ_term = targ_term
          @transform_query = transform_query
          @transform_matchings = transform_matchings
        end
        
        def compile(context)
          compound_rule = nil
          vocabulary_identifier = context.vocabulary.identifying_role_values
          constellation = context.vocabulary.constellation
          if (target_ot = constellation.ObjectType[[vocabulary_identifier, @targ_term.term]]).nil?
            raise "Target object '#{@targ_term.term}' of transformation must be a valid object type"
          end
          
          if @transform_query.is_a?(ActiveFacts::CQL::Compiler::Reference)
            if (source_ot = constellation.ObjectType[[vocabulary_identifier, @transform_query.term]]).nil?
              raise "Invalid source object '#{@transform_query.term}' for '#{@targ_term.term}' transformation"
            end
            compound_rule = constellation.CompoundTransformMatching(
                                  :new, :target_object_type => target_ot, :source_object_type => source_ot
                                )
          else
            query = Query.new(nil, @transform_query.flatten)
            query.constellation = constellation
            query.vocabulary = context.vocabulary
            if (source_query = query.compile).nil?
              raise "Invalid source query for '#{@targ_term.term}' transformation"
            end
            compound_rule = constellation.CompoundTransformMatching(
                                  :new, :target_object_type => target_ot, :source_query => source_query
                                )
          end
          
          @transform_matchings.each do |tr|
            trule = tr.compile(context)
            trule.compound_transform_matching = compound_rule
          end
          
          compound_rule
        end
      end

      class SimpleTransformMatching
        attr_accessor :targ_term, :transform_expr
        
        def initialize targ_term, transform_expr
          @targ_term = targ_term
          @transform_expr = transform_expr
        end
        
        def compile(context)
          vocabulary_identifier = context.vocabulary.identifying_role_values
          constellation = context.vocabulary.constellation
          if (target_ot = constellation.ObjectType[[vocabulary_identifier, @targ_term.term]]).nil?
            raise "Target object '#{@targ_term.term}' of transformation must be a valid object type"
          end
          
          expr = transform_expr.compile(context)
          @simple_rule = constellation.SimpleTransformMatching(:new, :target_object_type => target_ot, :expression => expr)
        end
      end
    end
  end
end
