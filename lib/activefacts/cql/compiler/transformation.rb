#
#       ActiveFacts CQL Parser.
#       Compiler classes relating to Transformation Rules.
#
# Copyright (c) 2017 Factil Pty Ltd. Read the LICENSE file.
#
module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser

      class Transformation < Definition
        attr_accessor :compound_transform_rule

        def initialize compound_transform_rule
          @compound_transform_rule = compound_transform_rule
        end
        
        def compile
          transform_rule = @compound_transform_rule.compile(@constellation, @vocabulary)     
          transformation = @constellation.Transformation(:new, :compound_transform_rule => transform_rule)
          # transformation.compound_transform_rule = transform_rule
          return transformation
        end
      end
      
      class CompoundTransformRule
        attr_accessor :targ_term, :transform_query, :transform_rules
        
        def initialize targ_term, transform_query, transform_rules
          @targ_term = targ_term
          @transform_query = transform_query
          @transform_rules = transform_rules
        end
        
        def compile(constellation, vocabulary)
          compound_rule = nil
          vocabulary_identifier = vocabulary.identifying_role_values
          if (target_ot = constellation.ObjectType[[vocabulary_identifier, @targ_term.term]]).nil?
            raise "Target object '#{@targ_term.term}' of transformation must be a valid object type"
          end
          
          if @transform_query.is_a?(ActiveFacts::CQL::Compiler::Reference)
            if (source_ot = constellation.ObjectType[[vocabulary_identifier, @transform_query.term]]).nil?
              raise "Invalid source object '#{@transform_query.term}' for '#{@targ_term.term}' transformation"
            end
            compound_rule = constellation.CompoundTransformRule(
                                  :new, :target_object_type => target_ot, :source_object_type => source_ot
                                )
          else
            query = Query.new(nil, @transform_query.flatten)
            query.constellation = constellation
            query.vocabulary = vocabulary
            if (source_query = query.compile).nil?
              raise "Invalid source query for '#{@targ_term.term}' transformation"
            end
            compound_rule = constellation.CompoundTransformRule(
                                  :new, :target_object_type => target_ot, :source_query => source_query
                                )
          end
          
          @transform_rules.each do |tr|
            trule = tr.compile(constellation, vocabulary)
            constellation.CompoundTransformPart(
                    :new, :compound_transform_rule => compound_rule, :transform_rule => trule
                  )
          end
          
          return compound_rule
        end
      end

      class ValueTransformRule
        attr_accessor :targ_term, :transform_expr
        
        def initialize targ_term, transform_expr
          @targ_term = targ_term
          @transform_expr = transform_expr
        end
        
        def compile(constellation, vocabulary)
          vocabulary_identifier = vocabulary.identifying_role_values
          if (target_ot = constellation.ObjectType[[vocabulary_identifier, @targ_term.term]]).nil?
            raise "Target object '#{@targ_term.term}' of transformation must be a valid object type"
          end
          
          constellation.ValueTransformRule(:new, :target_object_type => target_ot, expression: nil)
        end
      end
      
    end
  end
end
