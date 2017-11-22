#
# Test the compilation of Value Type Parameters
#

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)
require 'bundler/setup' # Set up gems listed in the Gemfile.

require 'activefacts/input/cql'

RSpec::Matchers.define :be_like do |expected|
  match do |actual|
    actual == expected
  end

  failure_message do
    'Output doesn\'t match expected, see diff'
  end

  diffable
end

def compile cql
  begin
    vocabulary = ActiveFacts::Input::CQL.readstring(cql)
    vocabulary.finalise
    vocabulary.constellation.ValueTypeParameter.values.map(&:describe) * "\n" + "\n" +
    vocabulary.constellation.ValueTypeParameterRestriction.values.map(&:value_type).uniq.map do |vt|
      "#{vt.name}(#{vt.all_value_type_parameter_restriction.map{|vtpr| "#{vtpr.value_type_parameter.name}=#{vtpr.value_range}"}*', '})"
    end*"\n"
  rescue => e
    e.message
  end
end

describe "Value Type Parameters" do
  dir = Pathname.new(__FILE__+'/../').relative_path_from(Pathname(Dir.pwd)).to_s
  cql = File.read("#{dir}/cql/vtp.cql")

  it "Produces the expected model for vtp.cql" do
    expected = <<END
ValueType 'Name' Parameter 'Encoding' is of type 'String'
Company Name(Encoding='ASCII')
Family Name(Encoding='latin1')
Farnarkle Name(Encoding=4)
Given Name(Encoding='utf8')
Name(Encoding=1..4, Encoding='ASCII'..'blarf', Encoding='latin1', Encoding='utf8')
Personal Name(Encoding='latin1', Encoding='utf8')
END
    actual = compile(cql)
    # puts 'v'*40; puts actual; puts '^'*40
    expect(actual.split(/\n/)).to be_like(expected.split(/\n/))
  end

  it "Fails with the right error when you use a value not in the allowed set of strings" do
    # Changing the base restrictions disallows assignments that use the old value
    actual = compile(cql.sub(/{'ASCII'/, "{'ascii'"))
    # puts 'v'*40; puts actual; puts '^'*40
    expected = %q{at line 10 value 'ASCII' is restricted by Name to [1..4, 'ascii'..'blarf', 'latin1', 'utf8']}
    expect(actual).to be_like(expected), "Output '#{actual}' doesn't match expected"
  end

  it "Fails with the right error when you use a value not in the allowed set of integers" do
    # Changing the base restrictions disallows assignments that use the old value
    actual = compile(cql.sub(/Encoding: 4/, "Encoding: 5"))
    # puts 'v'*40; puts actual; puts '^'*40
    expected = %q{at line 9 value 5 is restricted by Name to [1..4, 'ASCII'..'blarf', 'latin1', 'utf8']}
    expect(actual).to be_like(expected), "Output '#{actual}' doesn't match expected"
  end

  it "Fails with the right error when you try to change a restriction" do
    # Removing the word "Company" makes it look like we're re-assigning the restrictions on Name:
    actual = compile(cql.sub(%r{Company }, ""))
    # puts 'v'*40; puts actual; puts '^'*40
    expected = %q{at line 10 You can't change the existing restrictions on parameter Encoding of Name}
    expect(actual).to be_like(expected), "Output '#{actual}' doesn't match expected"
  end

  it "Fails with the right error when you widen a restriction on a subclass" do
    # Change the restriction on Personal Name:
    actual = compile(cql.sub(/{'latin1',/, "{'iso-8859-1',"))
    # puts 'v'*40; puts actual; puts '^'*40
    expected = %q{at line 11 value 'iso-8859-1' is restricted by Name to [1..4, 'ASCII'..'blarf', 'latin1', 'utf8']}
    expect(actual).to be_like(expected), "Output '#{actual}' doesn't match expected"
  end

end
