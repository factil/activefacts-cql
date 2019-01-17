#
#       ActiveFacts CQL Parser.
#       Manage the known Terms, both globally and within a CQL definition
#
# Copyright (c) 2019 Clifford Heath. Read the LICENSE file.
#

module ActiveFacts
  module CQL
    module AST
      module LeadID
        attr_accessor :term, :global_term
      end

      module TermNode
        def value             # Sometimes we just want the full term name
          lead_id.term
        end

        def global_term
          lead_id.global_term
        end

        def leading_adjective
          t = value
          gt = global_term
          if t.size > gt.size and t[-gt.size..-1] == gt
            adj = t[0...-gt.size-1]
            adj.sub!(/ /, '-') if !tail.elements[0].dbl.empty?
          end
          adj
        end

        def trailing_adjective
          t = value
          gt = global_term
          if t.size > gt.size and t[0...gt.size] == gt
            adj = t[gt.size+1..-1]
            adj.sub!(/ (\S*)\Z/, '-\1') if !tail.elements[-1].dbl.empty?
          end
          adj
        end

        def node_type
          :term
        end
      end

      module TermLANode
        include TermNode

        def ast quantifier = nil, function_call = nil, role_name = nil, value_constraint = nil, literal = nil, nested_clauses = nil
          ast = term.ast(quantifier, function_call, role_name, value_constraint, literal, nested_clauses)
          ast.leading_adjective = lead_id.text_value
          ast
        end
      end

      module NewTermName
        include TermNode

        def value
          t.elements.inject([
            id.value
          ]){|a, e| a << e.id.value}*' '
        end

        def node_type
          :term
        end
      end
    end

    module TermLookup
      # This contains a hash of the terms we know about, including all whole-word prefixes
      attr_reader :terms

      # Information needed while parsing a term:
      attr_reader :term, :global_term

      def initialize_term_lookup
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

      def new_local_name(name, kind)
        index_name(@role_names, name) && trace(:terms, "new #{kind} '#{name}'")
        true
      end

      # The methods named ending in ? are semantic predicates; if they return false this parse rule will fail.

      def term_starts?(s, lead_id)
        @term = @global_term = nil

        @term_part = s
        @context_saver = lead_id
        t = @terms[s] || @role_names[s] || system_term(s)
        if t
          # s is a prefix of the keys of t.
          if t[s]
            @global_term = @term = @term_part
            @context_saver.term = @term
            @context_saver.global_term = @global_term
          end
          trace :terms, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
        elsif @allowed_forward_terms.include?(@term_part)
          @term = @term_part
          @context_saver.term = @term
          @context_saver.global_term = @term
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
            @context_saver.term = @term
            @context_saver.global_term = @global_term
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

      def prescan_term_starts?(s, lead_id)
        @term = @global_term = nil

        @term_part = s
        @context_saver = lead_id
        t = @terms[s] || system_term(s)
        if t
          # s is a prefix of the keys of t.
          if t[s]
            @global_term = @term = @term_part
            @context_saver.term = @term
            @context_saver.global_term = @global_term
          end
          trace :terms, "Term #{t[s] ? "is" : "starts"} '#{@term_part}'"
        elsif @allowed_forward_terms.include?(@term_part)
          @term = @term_part
          @context_saver.term = @term
          @context_saver.global_term = @term
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
            @context_saver.term = @term
            @context_saver.global_term = @global_term
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
    end
  end
end
