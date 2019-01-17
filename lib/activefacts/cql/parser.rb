#
#       ActiveFacts CQL Parser.
#       The parser turns CQL strings into abstract syntax trees ready for semantic analysis.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'rubygems'
require 'treetop'
require 'delegate'
require_relative 'term_lookup'

# Include the Treetop files, which Polyglot will compile on the fly if precompiled ones aren't found:
require 'activefacts/cql/parser/CQLParser'

class Treetop::Runtime::SyntaxNode
  # node_type is used in colourising a parse tree
  def node_type
    terminal? ? :keyword : :composite
  end
end

module ActiveFacts
  module CQL
    class Parser < CQLParser  # Extend the Treetop-generated parser
      include TermLookup

      # Parser actions on SyntaxNodes have the @input available but not the parser.
      # Delegate input, so we have a handle to the parser in actions.
      class InputProxy < SimpleDelegator
        attr_reader :parser
        def initialize input, parser
          super(input)
          @parser = parser
        end
      end

      def initialize
        initialize_term_lookup
      end

      def unit?(s)
        # puts "Asking whether #{s.inspect} is a unit"
        true
      end

      def parse(input, options = {})
        input = InputProxy.new(input, self)
        super(input, options)
      end

      def parse_all(input, rule_name = nil, &block)
        self.root = rule_name if rule_name

        @index = 0  # Byte offset to start next parse
        @block = block
        self.consume_all_input = false
        asts = []
        begin
          tree = parse(InputProxy.new(input, self), :index => @index)
          unless tree 
            raise failure_reason || "not all input was understood" unless @index == input.size
            return nil  # No input, or no more input
          end
          ast = tree.ast
          unless @vocabulary_seen || !ast
            @vocabulary_seen = Compiler::Schema === ast
            raise "CQL files must begin with a schema or transform definition" unless @vocabulary_seen
          end
          if @block
            @block.call(ast, tree)
          else
            asts << ast
          end
        end until self.index == @input_length
        @block ? true : asts
      end
    end

  end

  Polyglot.register('cql', CQL::Parser)
end
