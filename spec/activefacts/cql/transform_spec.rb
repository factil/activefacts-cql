#
# Test the relational composition from CQL files by comparing generated CWM output
#

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)
require 'bundler/setup' # Set up gems listed in the Gemfile.

# require 'spec_helper'
require 'activefacts/input/cql'
require 'byebug'

# TRANS_CQL_DIR = Pathname.new(__FILE__+'/../../relational').relative_path_from(Pathname(Dir.pwd)).to_s
TRANS_CQL_DIR = Pathname.new(__FILE__+'/../cql').relative_path_from(Pathname(Dir.pwd)).to_s
TRANS_TEST_DIR = Pathname.new(__FILE__+'/..').relative_path_from(Pathname(Dir.pwd)).to_s

RSpec::Matchers.define :be_like do |expected|
  match do |actual|
    actual == expected
  end

  failure_message do
    'Output doesn\'t match expected, see diff'
  end

  diffable
end

def prepare(expected_dir, actual_dir, out_file)
  expected = expected_dir + '/' + out_file
  actual = actual_dir + '/' + out_file
  begin
    expected_text = File.read(expected)
  rescue Errno::ENOENT => exception
  end
  [expected, actual, expected_text]
end

def compare_save(expected_text, output_text, actual, expected)
  if expected_text != output_text
    File.write(actual, output_text)
  else
    File.delete(actual) rescue nil
  end

  if expected_text
    expect(output_text).to be_like(expected_text), "Output #{actual} doesn't match expected #{expected}"
  else
    pending "Actual output in #{actual} can't be compared with missing expected file #{expected}"
    expect(expected_text).to_not be_nil, "I don't know what to expect"
  end
end

describe "TRANSFORM rules from CQL" do
  dir = ENV['CQL_DIR'] || TRANS_CQL_DIR

  $stderr.puts "dir is #{dir}"

  actual_dir = (ENV['CQL_DIR'] ? '' : TRANS_TEST_DIR+'/') + 'actual'
  expected_dir = (ENV['CQL_DIR'] ? '' : TRANS_TEST_DIR+'/') + 'expected'
  Dir.mkdir actual_dir unless Dir.exist? actual_dir

  it "Produces the expected fact model for Personnel.cql" do
    cql_file = 'Personnel.cql'
    out_file = "Personnel.describe"

    expected, actual, expected_text = prepare(expected_dir, actual_dir, out_file)

    vocabulary = ActiveFacts::Input::CQL.readfile("#{dir}/#{cql_file}")
    vocabulary.finalise

    output = vocabulary.constellation.Concept.values.map(&:describe).sort * "\n"

    compare_save(expected_text, output, actual, expected)
  end
end
