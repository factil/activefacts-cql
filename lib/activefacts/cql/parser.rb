#
#       ActiveFacts CQL Parser.
#       The parser turns CQL strings into abstract syntax trees ready for semantic analysis.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'rubygems'
require 'treetop'

# These are Treetop files, which Polyglot will compile on the fly if precompiled ones aren't found:

require 'activefacts/cql/parser/CQLParser'

module ActiveFacts
  module CQL
    class Parser < CQLParser
    end
  end
end
require 'activefacts/cql/parser/nodes'

class Treetop::Runtime::SyntaxNode
  def node_type
    terminal? ? :keyword : :composite
  end
end

module ActiveFacts
  module CQL
    module Terms
      class SavedContext < Treetop::Runtime::SyntaxNode
        attr_accessor :context
      end
    end

    # Extend the generated parser:
    class Parser
      include ActiveFacts

      # The Context manages some key information revealed or needed during parsing
      # These methods are semantic predicates; if they return false this parse rule will fail.
      class Context
        attr_reader :term, :global_term
        attr_reader :terms

        def initialize(parser)
          @parser = parser
          @terms = {}
          @role_names = {}
          @allowed_forward_terms = []
        end

        def object_type(name, kind)
          index_name(@terms, name) && trace(:context, "new #{kind} '#{name}'")
          true
        end

        def reset_role_names
          trace :context, "\tresetting role names #{@role_names.keys.sort*", "}" if @role_names && @role_names.size > 0
          @role_names = {}
        end

        def allowed_forward_terms(terms)
          @allowed_forward_terms = terms
        end

        def new_leading_adjective_term(adj, term)
          index_name(@role_names, "#{adj} #{term}", term) && trace(:context, "new compound term '#{adj}- #{term}'")
          true
        end

        def new_trailing_adjective_term(adj, term)
          index_name(@role_names, "#{term} #{adj}", term) && trace(:context, "new compound term '#{term} -#{adj}'")
          true
        end

        def role_name(name)
          index_name(@role_names, name) && trace(:context, "new role '#{name}'")
          true
        end

        def term_starts?(s, context_saver)
          @term = @global_term = nil

          @term_part = s
          @context_saver = context_saver
          t = @terms[s] || @role_names[s] || system_term(s)
          if t
            # s is a prefix of the keys of t.
            if t[s]
              @global_term = @term = @term_part
              @context_saver.context = {:term => @term, :global_term => @global_term }
            end
            trace :context, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
          elsif @allowed_forward_terms.include?(@term_part)
            @term = @term_part
            @context_saver.context = {:term => @term, :global_term => @term }
            trace :context, "Term #{s} is an allowed forward"
            return true
          end
          t
        end

        def term_continues?(s)
          @term_part = "#{@term_part} #{s}"
          t = @terms[@term_part]
          r = @role_names[@term_part]
          if t && (!r || !r[@term_part])    # Part of a term and not a complete role name
            w = "term"
          else
            t = r
            w = "role_name"
          end
          if t
            trace :context, "Multi-word #{w} #{t[@term_part] ? 'ends at' : 'continues to'} #{@term_part.inspect}"

            # Record the name of the full term and the underlying global term:
            if t[@term_part]
              @term = @term_part if t[@term_part]
              @global_term = (t = t[@term_part]) == true ? @term_part : t
              trace :context, "saving context #{@term}/#{@global_term}"
              # trace :context, "@terms =\n\t#{@terms.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
              # trace :context, "@role_names =\n\t#{@role_names.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
              @context_saver.context = {:term => @term, :global_term => @global_term }
            end
          end
          t
        end

        def term_complete?
          return true if @allowed_forward_terms.include?(@term)
          return true if system_term(@term)
          result = ((t = @terms[@term] and t[@term]) or (t = @role_names[@term] and t[@term]))
          trace :context, "term #{@term} is #{result ? '' : 'in'}complete"
          result
        end

        def global_term_starts?(s, context_saver)
          @term = @global_term = nil

          @term_part = s
          @context_saver = context_saver
          t = @terms[s] || system_term(s)
          if t
            # s is a prefix of the keys of t.
            if t[s]
              @global_term = @term = @term_part
              @context_saver.context = {:term => @term, :global_term => @global_term }
            end
            trace :context, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
          elsif @allowed_forward_terms.include?(@term_part)
            @term = @term_part
            @context_saver.context = {:term => @term, :global_term => @term }
            trace :context, "Term #{s} is an allowed forward"
            return true
          end
          t
        end

        def global_term_continues?(s)
          @term_part = "#{@term_part} #{s}"
          t = @terms[@term_part]
          if t
            trace :context, "Multi-word term #{t[@term_part] ? 'ends at' : 'continues to'} #{@term_part.inspect}"

            # Record the name of the full term and the underlying global term:
            if t[@term_part]
              @term = @term_part if t[@term_part]
              @global_term = (t = t[@term_part]) == true ? @term_part : t
              trace :context, "saving context #{@term}/#{@global_term}"
              # trace :context, "@terms =\n\t#{@terms.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
              @context_saver.context = {:term => @term, :global_term => @global_term }
            end
          end
          t
        end

        def system_term(s)
          false
        end

        def unit? s
          @parser.unit? s
        end

      private
        # Index the name by all prefixes
        def index_name(index, name, value = true)
          added = false
          words = name.split(/\s+/)
          words.inject("") do |n, w|
            # Index all prefixes up to the full term
            n = n.empty? ? w : "#{n} #{w}"
            index[n] ||= {}
            added = true unless index[n][name]
            index[n][name] = value    # Save all possible completions of this prefix
            n
          end
          added
        end
      end

      class InputProxy
        attr_reader :context, :parser

        def initialize(input, context, parser)
          @input = input
          @context = context
          @parser = parser
        end

        def length
          @input.length
        end

        def size
          length
        end

        def [](*a)
          @input[*a]
        end

        def index(*a)
          @input.index(*a)
        end

        def line_of(x)
          @input.line_of(x)
        end

        def column_of(x)
          @input.column_of(x)
        end
      end

      def context
        @context ||= Context.new(self)
      end

      def unit?(s)
        # puts "Asking whether #{s.inspect} is a unit"
        true
      end

      def parse(input, options = {})
        input = InputProxy.new(input, context, self) unless input.respond_to?(:context)
        super(input, options)
      end

      def parse_all(input, rule_name = nil, &block)
        self.root = rule_name if rule_name

        @index = 0  # Byte offset to start next parse
        @block = block
        self.consume_all_input = false
        nodes = []
        begin
          node = parse(InputProxy.new(input, context, self), :index => @index)
          unless node 
            raise failure_reason || "not all input was understood" unless @index == input.size
            return nil  # No input, or no more input
          end
          unless @vocabulary_seen || !node.ast
            @vocabulary_seen = Compiler::Vocabulary === node.ast
            raise "CQL files must begin with a vocabulary, schema or transform definition" unless @vocabulary_seen
          end
          if @block
            @block.call(node)
          else
            nodes << node
          end
        end until self.index == @input_length
        @block ? true : nodes
      end
    end

  end

  Polyglot.register('cql', CQL::Parser)
end
