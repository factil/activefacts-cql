#
# ActiveFacts tests: Test the CQL parser by looking at its parse trees.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'spec_helper'

describe "ASTs from Derived Fact Types with expressions" do
  it "should parse a simple comparison clause" do
    expect(%q{
      each combination FamilyName, GivenName occurs at most one time in Competitor has FamilyName, Competitor has GivenName;
    }).to parse_to_ast \
      "PresenceConstraint over [[{Competitor} \"has\" {FamilyName}], [{Competitor} \"has\" {GivenName}]] -1 over ({FamilyName}, {GivenName})"
  end
end
