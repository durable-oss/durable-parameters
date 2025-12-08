#!/usr/bin/env rake
begin
  require "bundler/setup"
  require "bundler/gem_tasks"
rescue LoadError
  raise "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "rdoc/task"

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "StrongParameters"
  rdoc.options << "--line-numbers"
  rdoc.rdoc_files.include("README.md")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/*_test.rb"
  t.verbose = false
end

Rake::TestTask.new("test:integration:sinatra") do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/integration/sinatra_adapter_test.rb"
  t.verbose = false
end

Rake::TestTask.new("test:integration:rage") do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/integration/rage_adapter_test.rb"
  t.verbose = false
end

Rake::TestTask.new("test:integration:hanami") do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/integration/hanami_adapter_test.rb"
  t.verbose = false
end

Rake::TestTask.new("test:integration:rails") do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/integration/rails_adapter_test.rb"
  t.verbose = false
end

Rake::TestTask.new("test:integration:controller_generator") do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/integration/controller_generator_test.rb"
  t.verbose = false
end

desc "Run all integration tests"
task "test:integration" => ["test:integration:sinatra", "test:integration:rage", "test:integration:hanami", "test:integration:rails", "test:integration:controller_generator"]

desc "Run unit tests and integration tests"
task "test:all" => [:test, "test:integration"]

task default: :test
