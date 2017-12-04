module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser

      class Unit < Definition
        def initialize singular, plural, numerator, denominator, offset, base_units, approximately, ephemera_url
          @singular = singular
          @plural = plural
          @numerator, @denominator = numerator, denominator
          @offset = offset
          @base_units = base_units  # An array of pairs, each [unit_name, power]
          @approximately = approximately
          @ephemera_url = ephemera_url
        end

        def compile
          if (@numerator.to_f / @denominator.to_i != 1.0)
            coefficient = @constellation.Coefficient(
                @numerator,
                @denominator.to_i,
                !@approximately
                # REVISIT: activefacts-api is complaining at present. The following is better and should work:
                # :numerator => @numerator,
                # :denominator => @denominator.to_i,
                # :is_precise => !@approximately
              )
          else
            coefficient = nil
          end
          @offset = nil if @offset.to_f == 0

          trace :units, "Defining new unit #{@singular}#{@plural ? "/"+@plural : ""}" do
            trace :units, "Coefficient is #{coefficient.numerator}#{coefficient.denominator != 1 ? "/#{coefficient.denominator}" : ""} #{coefficient.is_precise ? "exactly" : "approximately"}" if coefficient
            trace :units, "Offset is #{@offset}" if @offset
            raise "Redefinition of unit #{@singular}" if @constellation.Unit.values.detect{|u| u.name == @singular}
            raise "Redefinition of unit #{@plural}" if @constellation.Unit.values.detect{|u| u.name == @plural}
            unit = @constellation.Unit(:new,
                :name => @singular,
                :plural_name => @plural,
                :coefficient => coefficient,
                :offset => @offset,
                :is_fundamental => @base_units.empty?,
                :ephemera_url => @ephemera_url,
                :vocabulary => @vocabulary
              )
            @base_units.each do |base_unit, exponent|
              base = @constellation.Unit.values.detect{|u| u.name == base_unit || u.plural_name == base_unit }
              trace :units, "Base unit #{base_unit}^#{exponent} #{base ? "" : "(implicitly fundamental)"}"
              base ||= @constellation.Unit(:new, :name => base_unit, :is_fundamental => true, :vocabulary => @vocabulary)
              @constellation.Derivation(:derived_unit => unit, :base_unit => base, :exponent => exponent)
            end
=begin
            if @plural
              plural_unit = @constellation.Unit(:new,
                  :name => @plural,
                  :is_fundamental => false,
                  :vocabulary => @vocabulary
                )
              @constellation.Derivation(:derived_unit => plural_unit, :base_unit => unit, :exponent => 1)
            end
=end
            unit
          end
        end

        def inspect
          to_s
        end

        def to_s
          super + "Unit(#{
            @singular
          }#{
            @plural ? '/'+@plural : ''
          }) is #{
            @numerator
          }/#{
            @denominator
          }+#{
            @offset
          } #{
            @base_units.map{|b,e|
              b+'^'+e.to_s
            }*'*'
          }"
        end
      end

      class ValueType < ObjectType
        def initialize name, base, parameters, unit, value_constraint, pragmas, context_note, auto_assigned_at
          super name
          @base_type_name = base
          @parameters = parameters
          @unit = unit
          @value_constraint = value_constraint
          @pragmas = pragmas
          @context_note = context_note
          @auto_assigned_at = auto_assigned_at
        end

        def compile
          ordered_parameters, named_parameters = @parameters.partition{|p| Integer === p}
          length, scale = *ordered_parameters

          # Create the base type unless it already exists:
          base_type = nil
          if (@base_type_name != @name)
            unless base_type = @vocabulary.valid_value_type_name(@base_type_name)
              base_type = @constellation.ValueType(@vocabulary, @base_type_name, :concept => :new)
            end
          end

          # Create and initialise the ValueType:
          vt = @vocabulary.valid_value_type_name(@name) ||
            @constellation.ValueType(@vocabulary, @name, :concept => :new)

          # Apply independence:
          vt.is_independent = true if @pragmas.delete('independent')

          # Apply pragmas:
          @pragmas.each do |p|
            @constellation.ConceptAnnotation(:concept => vt.concept, :mapping_annotation => p)
          end if @pragmas

          # Apply supertype
          if base_type and base_type != vt
            raise "You may not change the supertype of #{vt.name} from #{vt.supertype.name} to #{base_type.name}" if vt.supertype && vt.supertype != base_type
            vt.supertype = base_type
          end

          # Apply ordered parameters:
          if length
            raise "You may not change the length of #{vt.name} from #{vt.length} to #{length}" if vt.length && vt.length != length
            vt.length = length
          end
          if scale
            raise "You may not change the scale of #{vt.name} from #{vt.scale} to #{scale}" if vt.scale && vt.scale != scale
            vt.scale = scale
          end
          vt.transaction_phase = @auto_assigned_at

          unless @unit.empty?
            unit_name, exponent = *@unit[0]
            unit = @constellation.Name[unit_name].unit ||
              @constellation.Name[unit_name].plural_named_unit
            raise "Unit #{unit_name} for value type #{@name} is not defined" unless unit
            if exponent != 1
              base_unit = unit
              unit_name = base_unit.name+"^#{exponent}"
              unless unit = @constellation.Unit.detect{|k,v| v.name == unit_name } 
                # Define a derived unit (these are skipped on output)
                unit = @constellation.Unit(:new,
                      :vocabulary => @vocabulary,
                      :name => unit_name,
                      :is_fundamental => false
                    )
                @constellation.Derivation(unit, base_unit).exponent = exponent
              end
            end
            raise "You may not change the units of #{vt.name} from #{vt.unit.describe} to #{unit.describe}" if vt.unit && vt.unit != unit
            vt.unit = unit
          end

          # Apply a value constraint:
          if @value_constraint
            @value_constraint.constellation = @constellation  # Pass constellation to the value_constraint compiler
            raise "#{vt.name} is already constrained to #{vt.value_constraint.describe} so you can't change it to #{@value_constraint.describe}" if vt.value_constraint && vt.value_constraint != value_constraint
            vt.value_constraint = @value_constraint.compile
          end

          # Apply a context note:
          if @context_note
            @context_note.compile(@constellation, vt)
          end

          # Apply named parameter (definitions, restrictions, and settings):
          trace :vtp, "Applying named parameters for #{@name}" do
            named_parameters.each do |(kind, vtp_name, *rest)|
              # Look up an existing definition of the parameter:
              vtp = nil
              vt.supertypes_transitive.detect do |st|
                vtp = st.all_value_type_parameter.detect{|evtp| evtp.name == vtp_name}
              end

              trace :vtp, "Applying #{kind} of named parameter #{vtp_name}" do
                restrictions = nil
                case kind
                when :definition
                  raise "You may not redefine parameter #{vtp_name} of #{vt.name}" if vtp
                  trace :vtp, "Defining parameter #{vtp_name} for #{vt.name}" do
                    parameter_value_type_name = rest.shift.term
                    parameter_value_type = @vocabulary.valid_value_type_name(parameter_value_type_name)
                    raise "Type #{parameter_value_type_name} for parameter #{vtp_name} of #{vt.name} is not defined" unless parameter_value_type
                    vtp = @constellation.ValueTypeParameter(value_type: vt, name: vtp_name, parameter_value_type: parameter_value_type)
                    restrictions = rest[0]
                  end

                when :restriction
                  raise "parameter #{vtp_name} of #{vt.name} is not defined" unless vtp
                  trace :vtp, "Restricting parameter #{vtp_name} for #{vt.name} to #{rest[0].inspect}"
                  restrictions = rest[0]

                when :setting
                  raise "parameter #{vtp_name} of #{vt.name} is not defined" unless vtp
                  # A Setting is a single-valued restriction
                  trace :vtp, "Setting parameter #{vtp_name} for #{vt.name} to #{[rest[0]].inspect}"
                  restrictions = [rest[0]]
                else
                  raise "AST error: unknown valuetype parameter #{kind}"
                end

                if restrictions && restrictions[0] == :value
                  # This is a value restriction which perhaps sets the RestrictionStyle
                  value = restrictions[1]
                  vtp.restriction_style = restrictions[2]
                  case restrictions[2]
                  when '', nil
                    restrictions = [[value, value]]
                  when 'min'
                    restrictions = [[value, nil]]
                  when 'max'
                    restrictions = [[nil, value]]   # Or should it be [0, value]? But we can get that using a range...
                  end
                  trace :vtp, "Setting value for parameter #{vtp_name} for #{vt.name} to #{value.inspect} with style #{vtp.restriction_style.inspect}"
                end

                if restrictions
                  # Find all ValueTypeParameterRestrictions for this parameter in this type's closest restricted supertype
                  vtprs = nil
                  restricted_supertype = nil
                  vt.supertypes_transitive.detect do |st|
                    vtprs = st.all_value_type_parameter_restriction.select{|evtpr| evtpr.value_type_parameter == vtp}
                    vtprs = nil if vtprs.empty?
                    restricted_supertype = st
                    trace :vtp, "Existing #{vtp_name} restriction on #{st.name} allows #{vt.name} to use #{vtprs.map(&:value_range).inspect}" if vtprs
                    vtprs
                  end

                  if vtprs && vt == restricted_supertype
                    raise "You can't change the existing restrictions on parameter #{vtp_name} of #{vt.name}"
                  end

                  trace :vtp, "Restricting parameter #{vtp_name}#{vt != vtp.value_type ? " (of #{vtp.value_type.name})" : ''} for #{vt.name} to #{restrictions.inspect}" do
                    restrictions.each do |restriction|

                      min, max = Array === restriction ? restriction : [restriction, restriction]
                      value_range = @constellation.ValueRange(
                        min && @constellation.Bound(:value => assert_literal_value(min), :is_inclusive => true),
                        max && @constellation.Bound(:value => assert_literal_value(max), :is_inclusive => true)
                      )

                      # This restriction may not widen the supertype's restriction:
                      if vtprs && !vtprs.detect{|r| r.value_range.includes?(value_range)}
                        raise "#{vtp_name} of #{@name} may not be set to #{restriction} because #{vtprs[0].value_type.name} restricts it to #{vtprs.map(&:value_range).map(&:inspect)*', '}"
                      end
                      @constellation.ValueTypeParameterRestriction(value_type: vt, value_type_parameter: vtp, value_range: value_range)
                    end
                  end
                end
              end
            end
          end

          vt
        end

        def to_s
          "ValueType: #{super} is written as #{
              @base_type_name
            }#{
              @parameters.size > 0 ? "(#{ @parameters.map{|p|p.to_s}*', ' })" : ''
            }#{
              @unit && @unit.length > 0 ? " in #{@unit.inspect}" : ''
            }#{
              @value_constraint ? " "+@value_constraint.to_s : ''
            }#{
              @pragmas.size > 0 ? ", pragmas [#{@pragmas*','}]" : ''
            };"
        end
      end
    end
  end
end
