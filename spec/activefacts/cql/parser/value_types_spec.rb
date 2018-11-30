#
# ActiveFacts tests: Test the CQL parser by looking at its parse trees.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'spec_helper'

describe "Value Types" do
  ValueTypes = [
    [ "a is written as b(1, 2) in inch restricted to { 3 .. 4 } inch ;",
      ['ValueType: a is written as b(1, 2) in [["inch", 1]] ValueConstraint to ([3..4]) in [["inch", 1]];']
    ],
#    [ "a c  is written as b(1, 2) inch restricted to { 3 .. 4 } inch ;",
#      [["a c", [:value_type, "b", [1, 2], "inch", [[3, 4]]]]]
#    ],
  ]

  before :each do
    @parser = TestParser.new
    @parser.parse_all("schema test;", :definition)
  end

  ValueTypes.each do |c|
    source, expected_ast = *c
    it "should parse #{source.inspect}" do
      asts = @parser.parse_all(source, :definition)

      puts @parser.failure_reason unless asts
      expect(asts).to_not be_nil

      canonical_form = asts.map(&:to_s)
      if expected_ast
        expect(canonical_form).to eq expected_ast
      else
        puts "#{source.inspect} should compile to"
        puts "\t#{canonical_form}"
      end
    end
  end
end
