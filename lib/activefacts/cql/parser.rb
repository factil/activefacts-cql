#
#       ActiveFacts CQL Parser.
#       The parser turns CQL strings into abstract syntax trees ready for semantic analysis.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'rubygems'
require 'treetop'
require 'delegate'

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
    module Terms
      class SavedContext < Treetop::Runtime::SyntaxNode
        attr_accessor :context
      end
    end

    # Extend the generated parser:
    class Parser < CQLParser
      include ActiveFacts

      # Parser actions on SyntaxNodes have the @input available but not the parser.
      # Delegate input, so we have a handle to the parser in actions.
      class InputProxy < SimpleDelegator
        attr_reader :parser
        def initialize input, parser
          super(input)
          @parser = parser
        end
      end

      # This contains a hash of the terms we know about, including all whole-word prefixes
      attr_reader :terms

      # Information needed while parsing a term:
      attr_reader :term, :global_term

      def initialize
        @terms = {}
        @role_names = {}
        @allowed_forward_terms = []
      end

      def new_object_type_name(name, kind)
        index_name(@terms, name) && trace(:terms, "new #{kind} '#{name}'")
        true
      end

      def reset_role_names
        trace :terms, "\tresetting role names #{@role_names.keys.sort*", "}" if @role_names && @role_names.size > 0
        @role_names = {}
      end

      def allowed_forward_terms(terms)
        @allowed_forward_terms = terms
      end

      def new_leading_adjective_term(adj, term)
        index_name(@role_names, "#{adj} #{term}", term) && trace(:terms, "new compound term '#{adj}- #{term}'")
        true
      end

      def new_trailing_adjective_term(adj, term)
        index_name(@role_names, "#{term} #{adj}", term) && trace(:terms, "new compound term '#{term} -#{adj}'")
        true
      end

      def new_role_name(name)
        index_name(@role_names, name) && trace(:terms, "new role '#{name}'")
        true
      end

      # The methods named ending in ? are semantic predicates; if they return false this parse rule will fail.

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
          trace :terms, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
        elsif @allowed_forward_terms.include?(@term_part)
          @term = @term_part
          @context_saver.context = {:term => @term, :global_term => @term }
          trace :terms, "Term #{s} is an allowed forward"
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
          trace :terms, "Multi-word #{w} #{t[@term_part] ? 'ends at' : 'continues to'} #{@term_part.inspect}"

          # Record the name of the full term and the underlying global term:
          if t[@term_part]
            @term = @term_part if t[@term_part]
            @global_term = (t = t[@term_part]) == true ? @term_part : t
            trace :terms, "saving context #{@term}/#{@global_term}"
            # trace :terms, "@terms =\n\t#{@terms.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
            # trace :terms, "@role_names =\n\t#{@role_names.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
            @context_saver.context = {:term => @term, :global_term => @global_term }
          end
        end
        t
      end

      def term_complete?
        return true if @allowed_forward_terms.include?(@term)
        return true if system_term(@term)
        result = ((t = @terms[@term] and t[@term]) or (t = @role_names[@term] and t[@term]))
        trace :terms, "term #{@term} is #{result ? '' : 'in'}complete"
        result
      end

      def prescan_term_starts?(s, context_saver)
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
          trace :terms, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
        elsif @allowed_forward_terms.include?(@term_part)
          @term = @term_part
          @context_saver.context = {:term => @term, :global_term => @term }
          trace :terms, "Term #{s} is an allowed forward"
          return true
        end
        t
      end

      def prescan_term_continues?(s)
        @term_part = "#{@term_part} #{s}"
        t = @terms[@term_part]
        if t
          trace :terms, "Multi-word term #{t[@term_part] ? 'ends at' : 'continues to'} #{@term_part.inspect}"

          # Record the name of the full term and the underlying global term:
          if t[@term_part]
            @term = @term_part if t[@term_part]
            @global_term = (t = t[@term_part]) == true ? @term_part : t
            trace :terms, "saving context #{@term}/#{@global_term}"
            # trace :terms, "@terms =\n\t#{@terms.map{|k,v| "#{k} => #{v}"} * "\n\t"}"
            @context_saver.context = {:term => @term, :global_term => @global_term }
          end
        end
        t
      end

      def system_term(s)
        # We don't define any system terms here, but an example would be "Now" - the transaction's clock.
        false
      end

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

      def allow_forward_terms_in role_list
        forwards = role_list.
          map do |role|
            next nil if role.is_a?(Compiler::Clause) # Can't forward-reference unaries
            next nil if role.leading_adjective or role.trailing_adjective
            role.term
          end.
          compact
        allowed_forward_terms(forwards)
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
