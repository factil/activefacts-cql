#
# ActiveFacts tests: Test the CQL parser by looking at its parse trees.
# Copyright (c) 2008 Clifford Heath. Read the LICENSE file.
#
require 'spec_helper'

describe "Parsing Invalid Numbers and Strings" do
  it "should fail to parse an octal number containing non-octal digits" do
    expect("aa is written as b(08);").
    to fail_to_parse /Expected one of .* after aa is written as b\($/
  end

  it "should fail to parse a hexadecimal number containing non-hexadecimal digits" do
    expect("aa is written as b(0xDice);").
    to fail_to_parse /Expected one of .* after aa is written as b\($/
  end

  it "should fail to parse a negative number with an intervening space" do
    expect("aa is written as b(- 1);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse an explicit positive number with an intervening space" do
    expect("aa is written as b(+ 1);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse a negative octal number" do
    expect("aa is written as b(-077);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse a negative hexadecimal number" do
    expect("aa is written as b(-0xFace);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse invalid real numbers (no digits before or nonzero after the point)" do
    expect("aa is written as b(.0);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse invalid real numbers (no digits after or nonzero before the point)" do
    expect("aa is written as b(0.);").
    to fail_to_parse /Expected .* after aa is written as b\(/
  end

  it "should fail to parse a number with illegal whitespace before the exponent" do
    expect("inch converts to 1 inch; aa is written as b() inch ^2 ; ").
    to fail_to_parse /Expected .* after /
  end

  it "should fail to parse a number with illegal whitespace around the exponent" do
    expect("inch converts to 1 inch; aa is written as b() inch^ 2 ; ").
    to fail_to_parse /Expected .* after /
  end

  it "should fail to parse a string with an illegal octal escape" do
    expect("aa is written as b() restricted to { '\\7a' };").
    to fail_to_parse /Expected .* aa is written as b\(\) restricted to $/
  end

  it "should fail to parse a string with a control character" do
    expect("aa is written as b() restricted to { '\001' };").
    to fail_to_parse /Expected .* aa is written as b\(\) restricted to $/
  end

  it "should fail to parse a string with a control character" do
    expect("aa is written as b() restricted to { '\n' };").
    to fail_to_parse /Expected .* aa is written as b\(\) restricted to $/
  end

  it "should fail to parse a cross-typed range" do
    expect("aa is written as b() restricted to { 0..'A' };").
    to fail_to_parse /Expected .* after aa is written as b\(\) restricted to \{ 0\.\./

    expect("aa is written as b() restricted to { 'a'..27 };").
    to fail_to_parse /Expected .* after aa is written as b\(\) restricted to \{ 'a'\.\./
  end

end
