#       Compile a CQL string into an ActiveFacts vocabulary.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'activefacts/metamodel'
require 'activefacts/cql/parser'
require 'activefacts/cql/compiler/asts'
require 'activefacts/cql/compiler/shared'
require 'activefacts/cql/compiler/value_type'
require 'activefacts/cql/compiler/entity_type'
require 'activefacts/cql/compiler/clause'
require 'activefacts/cql/compiler/fact_type'
require 'activefacts/cql/compiler/expression'
require 'activefacts/cql/compiler/fact'
require 'activefacts/cql/compiler/constraint'
require 'activefacts/cql/compiler/query'
require 'activefacts/cql/compiler/informal'
require 'activefacts/cql/compiler/transform_rule'

module ActiveFacts
  module CQL
    class Compiler < ActiveFacts::CQL::Parser
      LANGUAGES = {
        'en' => 'English',
        'fr' => 'French',
        'cn' => 'Mandarin'
      }
      EXTENSIONS = ['fiml', 'fidl', 'fiql', 'cql']

      attr_reader :vocabulary

      def initialize filepath, options = {}
        @filepath = filepath
        super()
        if @constellation = options[:constellation]
          @vocabulary = @constellation.Vocabulary.values[0]
          # Initialise term lookup with existing object types
          @constellation.ValueType.values.each do |object_type|
            new_object_type_name(object_type.name, 'value type')
          end
          @constellation.EntityType.values.each do |object_type|
            new_object_type_name(object_type.name, 'entity type')
          end
        else
          @constellation = ActiveFacts::API::Constellation.new(ActiveFacts::Metamodel)
        end
        @constellation.loggers << proc{|*k| trace :apilog, k.inspect} if trace(:apilog)
        @language = nil
        @pending_import_topic = nil
        @pending_import_role = ''
        @pending_import_file_name = ''
        trace :file, "Parsing '#{@filepath}'"
      end

      def compile_file filepath
        old_filepath = @filepath
        @filepath = filepath
        File.open(filepath) do |f|
          compile(f.read)
        end
        @filepath = old_filepath
        @vocabulary
      end

      # Load the appropriate natural language module
      def detect_language
        @filepath =~ /.*\.(..)\.cql$/i
        language_code = $1
        @language = LANGUAGES[language_code] || 'English'
      end

      def include_language
        detect_language unless @langage
        require 'activefacts/cql/parser/Language/'+@language
        language_module = ActiveFacts::CQL.const_get(@language)
        extend language_module
      end

      # Mark any new Concepts as belonging to this topic
      def topic_flood
        @constellation.Concept.each do |key, concept|
          next if concept.topic
          trace :topic, "Colouring #{concept.describe} with #{@topic.topic_name}"
          concept.topic = @topic
        end
      end

      def create_import_if_pending new_topic
        if @pending_import_topic
          trace :import, "Topic #{@pending_import_topic.topic_name} imports #{new_topic.topic_name} as #{@pending_import_role} from file #{@pending_import_file_name}"

          @constellation.Import(
            topic: @pending_import_topic,
            precursor_topic: new_topic,
            import_role: @pending_import_role,
            file_name: @pending_import_file_name
          )

          @pending_import_topic = nil
          @pending_import_role = ''
          @pending_import_file_name = ''
        end
      end

      def compile input
        include_language

        @string = input

        # The syntax tree created from each parsed CQL statement gets passed to the block.
        # parse_all returns an array of the block's non-nil return values.
        ok = parse_all(@string, :definition) do |ast, tree|
          trace :parse, "Parsed '#{tree.text_value.gsub(/\s+/,' ').strip}'" do
            trace :lex, (proc { tree.inspect })
            begin
              next unless ast
              trace :ast, ast.inspect
              # "ast" is always a Compiler::Definition or subclass
              ast.constellation = @constellation
              ast.vocabulary = @vocabulary

              value = compile_definition ast, tree
              trace :definition, "Compiled to #{value.is_a?(Array) ? value.map{|v| v.verbalise}*', ' : value.verbalise}" if value
              if value.is_a?(ActiveFacts::Metamodel::Topic)
                topic_flood() if @topic
                create_import_if_pending(value)
                @topic = value
              elsif ast.is_a?(Compiler::Schema)
                topic_flood() if @topic
                @vocabulary = value
                @topic = @constellation.Topic(@vocabulary.name)
              end
            rescue => e
              # Augment the exception message, but preserve the backtrace
              start_line = @string.line_of(tree.interval.first)
              end_line = @string.line_of(tree.interval.last-1)
              lines = start_line != end_line ? "s #{start_line}-#{end_line}" : " #{start_line.to_s}"
              ne = StandardError.new("at line#{lines}, #{e.message.strip}")
              ne.set_backtrace(e.backtrace)
              raise ne
            end
          end
          topic_flood() if @topic
        end
        raise failure_reason unless ok
        vocabulary
      end

      def compile_import file, import_role, aliases
        saved_index = @index
        saved_block = @block
        saved_string = @string
        saved_input_length = @input_length
        old_filepath = @filepath
        @file = file
        @filepath = import_filepath(old_filepath, file)

        compile_import_file(@filepath, import_role)

      rescue => e
        ne = StandardError.new("In #{@filepath} #{e.message.strip}")
        ne.set_backtrace(e.backtrace)
        raise ne
      ensure
        @block = saved_block
        @index = saved_index
        @input_length = saved_input_length
        @string = saved_string
        @filepath = old_filepath
        nil
      end

      # redefine in subsclass for different behaviour
      def import_filepath(old_filepath, file)
        filepath = ''
        EXTENSIONS.each do |extension|
          filepath = File.dirname(old_filepath)+'/'+file+".#{extension}"
          break if File.exist?(filepath)
        end
        filepath
      end

      # redefine in subsclass for different behaviour
      def compile_import_file filepath, import_role
        # REVISIT: Save and use another @vocabulary for this file?
        File.open(filepath) do |f|
          compile_import_input(f.read, import_role)
        end
      end

      def compile_import_input input, import_role
        topic_external_name = @file

        if existing_topic = @constellation.Topic[[topic_external_name]]
          # topic has already been loaded, just build import
          trace :import, "Topic #{@topic.topic_name} has already been loaded, skip reload"
          import = @constellation.Import(
            topic: @topic, precursor_topic: existing_topic, 
            import_role: import_role, file_name: topic_external_name
          )
        else
          # topic has not been loaded previously, import topic
          saved_topic = @topic
          topic_flood() if @topic

          @pending_import_topic = saved_topic
          @pending_import_role = import_role
          @pending_import_file_name = topic_external_name

          trace :import, "Importing #{@filepath} into #{@topic.topic_name}" do
            ok = parse_all(input, nil, &@block)
          end
          @topic = saved_topic
        end
      end

      def compile_definition ast, tree
        ast.compile
      end

      def unit? s
        name = @constellation.Name[s]
        units = (!name ? [] : Array(name.unit) + Array(name.plural_named_unit)).uniq
        trace :units, "Looking for unit #{s}, got #{units.map{|u|u.name}.inspect}"
        units.size > 0
      end

    end
  end
end
