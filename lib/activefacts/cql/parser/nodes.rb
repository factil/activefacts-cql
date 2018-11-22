module ActiveFacts
  module CQL
    class Parser
      module Definitions
        def definitions
          elements.map do |e|
            e.value rescue $stderr.puts "Internal error: Don't call value() on #{e.inspect}"
          end
        end
      end

      module Definition
        def ast
          definition_body.ast
        end

        def body
          definition_body.text_value
        end
      end

      module Schema
        def ast
          Compiler::Schema.new(schema_name.value, false, vn.empty? ? nil : vn.value.text_value)
        end
      end

      module Transform
        def ast
          Compiler::Schema.new(schema_name.value, true, vn.empty? ? nil : vn.value.text_value)
        end
      end

      module FactType
        def ast
          ft = anonymous_fact_type.ast
          if !name.empty?
            # "each" is often used, and doesn't imply uniqueness
            ft.name = name.term_definition_name.value
            pragmas = name.mapping_pragmas.value
            pragmas << 'independent' if name.is_where.independent
            ft.pragmas = pragmas
          elsif !each.empty?
            # Handle the implied mandatory constraint on the appropriate role
            first_reading = ft.clauses[0]
            refs = first_reading.refs
            raise "Ambiguous 'each' implies mandatory on fact type of arity #{refs.size}" unless refs.size == 2
            q = refs[-1].quantifier
            if q
              q.min = 1  # Make the existing quantifier mandatory
            else
              refs[-1].quantifier = q = Compiler::Quantifier.new(1, nil)
            end
          end
          ft
        end
      end

      module AnonymousFactType
        def ast
          clauses_ast = query_clauses.ast
          conditions_ast =
            if !conditions.empty?
              returning = conditions.returning_clause.ast if conditions.respond_to?(:returning_clause)
              conditions.a.ast
            else
              []
            end
          value_derivation = clauses_ast.detect{|r| r.is_equality_comparison}
          if !value_derivation and
              conditions_ast.empty? and
              clauses_ast.detect{|r| r.includes_literals}
            raise "Fact instances may not contain conditions" unless conditions_ast.empty? && !returning
            Compiler::Fact.new clauses_ast
          elsif (clauses_ast.size == 1 &&
            clauses_ast[0].phrases.size == 1 &&
            (popname = clauses_ast[0].phrases[0]) &&
            !popname.is_a?(Compiler::Reference) &&
            conditions_ast.detect{|r| r.includes_literals}
          )
            Compiler::Fact.new conditions_ast, popname
          else
            Compiler::FactType.new nil, clauses_ast, conditions_ast, returning
          end
        end
      end

      module SumExpression
        def ast
          if tail.elements.empty?
            t0.ast
          else
            Compiler::Sum.new(t0.ast, *tail.elements.map{|e| e.op.text_value == '-' ? Compiler::Negate.new(e.t1.ast) : e.t1.ast})
          end
        end
      end

      module ProductExpression
        def ast
          if tail.elements.empty?
            f0.ast
          else
            Compiler::Product.new(f0.ast, *tail.elements.map{|e| e.op.text_value != '*' ? Compiler::Reciprocal.new(e.op.text_value, e.f1.ast) : e.f1.ast})
          end
        end
      end

      module LiteralFactor
        def ast
          Compiler::Literal.new(literal.value, u.empty? ? nil : u.text_value)
        end
      end

      module RoleQuantifier
        def ast
          Compiler::Quantifier.new(
            quantifier.value[0],
            quantifier.value[1],
            enforcement.ast,
            cn.empty? ? nil : cn.ast,
            mapping_pragmas.value
          )
        end
      end

      module Aggregate
        def ast
          raise "Not implemented: AST for '#{aggregate_operation.text_value} of #{term_or_unary.text_value}'"
          # This returns just the role with the nested clauses, which doesn't even work:
          term.ast(
            nil,      # No quantifier
            nil,      # No function call
            nil,      # No role_name
            nil,      # No value_constraint
            nil,      # No literal
            qualified_clauses.ast
          )
        end
      end

      module SimpleNounPhrase
        def ast
          if !q.empty? && q.quantifier.value
            quantifier = q.ast
          end
          if !lr.empty?
            if lr.respond_to?(:literal)
              literal = Compiler::Literal.new(lr.literal.value, lr.u.empty? ? nil : lr.u.text_value)
            end
            value_constraint = Compiler::ValueConstraint.new(lr.value_constraint.ast, lr.enforcement.ast) if lr.respond_to?(:value_constraint)
            raise "It is not permitted to provide both a literal value and a value constraint" if value_constraint and literal
          end

          nested_clauses =
            if oj.empty?
              nil
            else
              ast = oj.ast
              ast[0].conjunction = 'where'
              ast
            end
          player.ast(quantifier, value_constraint, literal, nested_clauses)
        end
      end

      class TermNode < Treetop::Runtime::SyntaxNode
        def ast quantifier = nil, function_call = nil, role_name = nil, value_constraint = nil, literal = nil, nested_clauses = nil
          t = x.context[:term]
          gt = x.context[:global_term]
          if t.size > gt.size and t[-gt.size..-1] == gt
            leading_adjective = t[0...-gt.size-1]
            leading_adjective.sub!(/ /, '-') if !tail.elements[0].dbl.empty?
          end
          if t.size > gt.size and t[0...gt.size] == gt
            trailing_adjective = t[gt.size+1..-1]
            trailing_adjective.sub!(/ (\S*)\Z/, '-\1') if !tail.elements[-1].dbl.empty?
          end
          Compiler::Reference.new(gt, leading_adjective, trailing_adjective, quantifier, function_call, role_name, value_constraint, literal, nested_clauses)
        end

        def value             # Sometimes we just want the full term name
          x.context[:term]
        end

        def node_type
          :term
        end
      end

      class TermLANode < TermNode
        def ast quantifier = nil, function_call = nil, role_name = nil, value_constraint = nil, literal = nil, nested_clauses = nil
          ast = term.ast(quantifier, function_call, role_name, value_constraint, literal, nested_clauses)
          ast.leading_adjective = head.text_value
          ast
        end
      end

      class TermDefinitionNameNode < TermNode
        def value
          t.elements.inject([
            id.value
          ]){|a, e| a << e.id.value}*' '
        end

        def node_type
          :term
        end
      end

      module ValueTypeParameterSetting
        def value
          [:setting, parameter_name.value, literal.value]
        end
      end

      module ValueTypeParameterDefinition
        def value
          [:definition, parameter_name.value, value_type.ast, vr.empty? ? nil : vr.parameter_restriction.values]
        end
      end

      module ValueTypeParameterRestriction
        def value
          [:restriction, parameter_name.value, parameter_restriction.values]
        end
      end
    end
  end
end
