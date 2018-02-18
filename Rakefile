require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :build => [:create_treetop_files, :clean_treetop_files]
task :create_treetop_files do
  cqlpath = File.expand_path('../lib/activefacts/cql/parser', __FILE__)
  Dir[cqlpath+"/**/*.treetop"].each do |tt|
    rb = tt.sub(/treetop\Z/, 'rb')
    sh(%Q{tt #{tt}})
  end
end
def clean_treetop_files
  cqlpath = File.expand_path('../lib/activefacts/cql/parser', __FILE__)
  Dir[cqlpath+"/**/*.treetop"].each do |tt|
    rb = tt.sub(/treetop\Z/, 'rb')
    File.unlink(rb) rescue nil
  end
end
task :clean_treetop_files do
  at_exit { clean_treetop_files }
end

desc "Bump gem version patch number"
task :bump do
  path = File.expand_path('../lib/activefacts/cql/version.rb', __FILE__)
  lines = File.open(path) do |fp| fp.readlines; end
  File.open(path, "w") do |fp|
    fp.write(
      lines.map do |line|
	line.gsub(/(VERSION *= *"[0-9.]*\.)([0-9]+)"\n/) do
	  version = "#{$1}#{$2.to_i+1}"
	  puts "Version bumped to #{version}\""
	  version+"\"\n"
	end
      end*''
    )
  end
end
