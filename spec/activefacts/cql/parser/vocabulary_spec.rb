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
    source, ast = *c
    it "should parse #{source.inspect}" do
      result = @parser.parse_all(source, :definition)

      puts @parser.failure_reason unless result
      expect(result).to_not be_nil

      canonical_form = result.map{|d| d.ast.to_s}
      if ast
        expect(canonical_form).to eql ast
      else
        puts "#{source.inspect} should compile to"
        puts "\t#{canonical_form}"
      end
    end
  end
end
