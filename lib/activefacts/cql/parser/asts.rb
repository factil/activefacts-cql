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

      module Import
        def ast
          Compiler::Import.new(
            import.input.parser, schema_name.value, i.empty? ? "topic" : i.value, vp.empty? ? nil : vp.pattern.text_value, alias_list.value
          )
        end
      end

      module InformalDefinition
        def ast
          kind = subject.signifier.text_value.to_sym
          subject_name = (kind == :each ? subject.term.text_value : subject.reading.text_value)
          phrases = subject.reading.elements.map(&:ast) if kind == :when
          Compiler::InformalDefinition.new(kind, subject_name, phrases, informal_description_body.text_value)
        end
      end

      module EntityType
        def ast
          name = term_definition_name.value
          clauses_ast = ec.empty? ? [] : ec.reading_clauses.ast
          pragmas = m1.value+m2.value
          pragmas << 'independent' if sup.independent
          context_note = !context.empty? ? context.ast : (!context2.empty? ? context2.ast : nil)
          Compiler::EntityType.new name, sup.supers, sup.ast, pragmas, clauses_ast, context_note
        end
      end

      module ReferenceMode
        def ast
          value_constraint = vc.empty? ? nil : vc.ast
          Compiler::ReferenceMode.new(i.value, value_constraint, value_type_parameters.values)
        end

        def mode
          i.value
        end
      end

      module IdentificationList
        def ast
          role_list.ast
        end

        def mode
          nil
        end
      end

      module UnaryTerm
        def ast
          t = term.ast
          t.role_name = ss.value if !ss.empty?
          if pre_text.elements.size == 0 && post_text.elements.size == 0
            t
          else
            pre_words = pre_text.elements.map{|w| w.id.text_value}
            post_words = post_text.elements.map{|w| w.id.text_value}
            Compiler::Clause.new(pre_words + [t] + post_words, [], nil)
          end
        end
      end

      module ForwardTerm
        # A forward-referenced entity type
        # REVISIT: A change in this rule might allow forward-referencing a multi-word term
        def ast
          Compiler::NounPhrase.new(id.text_value, nil, nil, nil, nil, ss.empty? ? nil : ss.value)
        end
      end

      module ValueType
        def ast
          name = term_definition_name.value
          params = value_type_parameters.values
          value_constraint = vc.empty? ? nil : vc.ast
          units = u.empty? ? [] : u.units.value
          auto_assigned_at = a.empty? ? nil : a.auto_assigned_at
          pragmas = m1.value+m2.value
          context_note = !context.empty? ? context.ast : (!context2.empty? ? context2.ast : nil)
          Compiler::ValueType.new name, base.value, params, units, value_constraint, pragmas, context_note, auto_assigned_at
        end
      end

      module UnitDefinition
        def ast
          singular = u.singular.text_value
          plural = u.plural.text_value.empty? ? nil : u.plural.p.text_value 
          if u.coeff.empty?
            raise "Unit definition requires either a coefficient or an ephemera URL" unless q.respond_to?(:ephemera)
            numerator,denominator = 1, 1
          else
            numerator, denominator = *u.coeff.ast
          end
          offset = u.o.text_value.empty? ? 0 : u.o.value
          bases = u.base.empty? ? [] : u.base.value
          approximately = q.respond_to?(:approximately) || u.conversion.approximate?
          ephemera = q.respond_to?(:ephemera) ? q.url.text_value : nil
          Compiler::Unit.new singular, plural, numerator, denominator, offset, bases, approximately, ephemera
        end
      end

      module Query
        def ast
          Compiler::FactType.new nil, [], query_clauses.ast, (r.empty? ? nil : r)
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
          end
          ft
        end
      end

      module QueryClauses
        def ast
          clauses_ast = qualified_clauses.ast
          ftail.elements.each{|e|
            conjunction = e.conjunction.text_value
            # conjunction = 'and' if conjunction == ','   # ',' means AND, but disallows left-contractions
            clauses_ast += e.qualified_clauses.ast(conjunction)
          }
          clauses_ast
        end
      end

      module QualifiedClauses
        def ast(conjunction = nil)
          r = contracted_clauses.ast  # An array of clause asts
          r[0].conjunction = conjunction
          # pre-qualifiers apply to the first clause, post_qualifiers and context_note to the last
          # REVISIT: This may be incorrect where the last is a nested clause
          r[0].certainty = certainty.value
          r[-1].qualifiers += pq.list unless pq.empty?
          r[-1].context_note = context.ast unless context.empty?
          r
        end
      end

      module ReadingClause
        def ast(conjunction = nil)
          contracted_noun, qualifiers, *contracted_clauses = *(
            if contraction.empty?
              [ nil, (pq.empty? ? nil : pq.list) ]
            else
              contraction.ast
            end
          )

          phrase_asts = phrases.elements.map{|p| p.phrase.ast}
          phrase_asts.push contracted_noun if contracted_noun
          clause = Compiler::Clause.new(phrase_asts, qualifiers, context.empty? ? nil : context.ast)
          clause.conjunction = conjunction
          [clause] + contracted_clauses
        end
      end

      module ComparisonContraction
        def ast
          c = Compiler::Comparison.new(comparator.text_value, noun_phrase.ast, e2.ast, certainty.value)
          c.conjunction = comparator.text_value
          [ noun_phrase.ast, pq.empty? ? [] : pq.list, c ]
        end
      end

      module ExpressionClauseContraction
        def ast
          noun_phrase, qualifiers, *clauses_ast = *contraction.ast
          clauses_ast[0].qualifiers += p.list unless p.empty? # apply post_qualifiers to the contracted clause
          # clauses_ast[0].conjunction = 'and' # AND is implicit for a contraction
          c = Compiler::Comparison.new(comparator.text_value, e1.ast, noun_phrase, certainty.value)
          [c] + clauses_ast
        end
      end

      module ExpressionExpressionContraction
        def ast
          c = Compiler::Comparison.new(comparator.text_value, e1.ast, e2.ast, certainty.value)
          [c]
        end
      end

      module ContractedClauses
        def ast
          asts = elements.map{ |r| r.ast }
          contracted_clauses = []
          qualifiers = []
          if asts[-1].is_a?(Array)        # A contraction (Array of [noun_phrase, qualifiers, *contracted_clauses])
            contracted_clauses = asts.pop         # Pull off the contracted_clauses
            contracted_noun_phrase = contracted_clauses.shift
            qualifiers = contracted_clauses.shift
            asts.push(contracted_noun_phrase)  # And replace it by the noun_phrase removed from the contracted_clauses
          end
          clause_ast = Compiler::Clause.new(asts, qualifiers)
          [clause_ast] + contracted_clauses
        end
      end

      module AnonymousFactType
        def ast
          clauses_ast = reading_clauses.ast
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
            !popname.is_a?(Compiler::NounPhrase) &&
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
            context.empty? ? nil : context.ast,
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
            else
              # There's something here, it must be a value_constraint
              value_constraint = lr.ast
            end
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
          Compiler::NounPhrase.new(gt, leading_adjective, trailing_adjective, quantifier, function_call, role_name, value_constraint, literal, nested_clauses)
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

      module Enforcement
        def ast
          Compiler::Enforcement.new(action.text_value, agent.empty? ? nil : agent.text_value)
        end
      end

      module PresenceConstraint
        def ast
          Compiler::PresenceConstraint.new context, enforcement.ast, clauses_ast, role_list_ast, quantifier_ast
        end
      end

      module SetConstraint
        def ast
          Compiler::SetExclusionConstraint.new context, enforcement.ast, clauses_ast, role_list_ast, quantifier_ast
        end
      end

      module SubsetConstraint
        def ast
          Compiler::SubsetConstraint.new context, enforcement.ast, [subset.ast, superset.ast]
        end
      end

      module SetEqualityConstraint
        def ast
          all_clauses = [clauses.ast, *tail.elements.map{|e| e.clauses.ast }]
          Compiler::SetEqualityConstraint.new context, enforcement.ast, all_clauses
        end
      end

      module ValueConstraint
        def ast
          Compiler::ValueConstraint.new(restricted_values.values, context.empty? ? nil : context.ast, enforcement.ast)
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

      module ContextNote
        def ast
          who = w.empty? ? nil : w.value
          ag = agreed.empty? ? [] : agreed.a.value
          Compiler::ContextNote.new context_type.value, description.text_value, who, ag
        end
      end

      module Variable
        def ast quantifier = nil, value_constraint = nil, literal = nil, nested_clauses = nil
          role_name = role_id.empty? ? nil : role_id.value
          derived.ast(quantifier, nil, role_name, value_constraint, literal, nested_clauses)
        end
      end

    end
  end
end
