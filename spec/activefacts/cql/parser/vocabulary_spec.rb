#
# ActiveFacts tests: Test the CQL parser by looking at its parse trees.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'spec_helper'

describe "Vocabulary definitions" do
  Vocabularies = [
    [ "vocabulary /* Stuff */ Foo ; // More stuff",
      ["Foo"]
    ],
    [ "schema /* Stuff */ Foo ; // More stuff",
      ["Foo"]
    ],
    [ "schema /* Stuff */ Foo /* intervening stuff */ Bar; // More stuff",
      ["Foo Bar"]
    ],
  ]

  before :each do
    @parser = TestParser.new
  end

  Vocabularies.each do |c|
    source, expected_ast = *c
    it "should parse #{source.inspect}" do
      asts = @parser.parse_all(source, :definition)

      puts @parser.failure_reason unless asts
      expect(asts).to_not be_nil

      canonical_form = asts.map(&:to_s)
      if expected_ast
        expect(canonical_form).to eql expected_ast
      else
        puts "#{source.inspect} should compile to"
        puts "\t#{canonical_form}"
      end
    end
  end
end
