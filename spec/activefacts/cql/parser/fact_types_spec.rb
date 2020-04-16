#
# ActiveFacts tests: Test the CQL parser by looking at its parse trees.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'spec_helper'

describe "Fact Types" do
  FactTypes = [
    [ "Foo has at most one Bar, Bar is of one Foo restricted to {1..10};",
      ["FactType: [{Foo} \"has\" {[..1] Bar}, {Bar} \"is of\" {[1..1] Foo ValueConstraint to ([1..10])}]"]
    ],
    [ "Bar(1) is related to Bar(2), primary-Bar(1) has secondary-Bar(2);",
      ["FactType: [{Bar(1)} \"is related to\" {Bar(2)}, {primary- Bar(1)} \"has\" {secondary- Bar(2)}]"]
    ],
    # REVISIT: Test all quantifiers
    # REVISIT: Test all post-qualifiers
#    [ "AnnualIncome is where Person has total- Income in Year: Person has total- Income.sum(), Income was earned in current- Time.Year() (as Year);",
#      [%q{FactType: AnnualIncome [{Person} "has" {total- Income} "in" {Year}] where {Person} "has" {total- Income}.sum() , {Income} "was earned in" {current- Time (as Year)}.Year()}]
#    ],
    [ "A is interesting : b- C has F -g;",
      [%q{FactType: Query: where {b- C} "has" {F -g} [{A} "is interesting"]}]
    ],
    [ "A has one pre-- bound B;",
      [%q{FactType: [{A} "has" {[1..1] pre-bound- B}]}]
    ]
    # REVISIT: Test all quantifiers
  ]

  before :each do
    @parser = TestParser.new
    @parser.parse_all("schema test;", :definition)
  end

  FactTypes.each do |c|
    source, expected_ast, definition = *c
    it "should parse #{source.inspect}" do
      expect(source).to parse_to_ast *expected_ast
    end
  end
end
