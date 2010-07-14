require 'rubygems'
require 'rake'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'dub/version'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "dub"
    gem.version = Dub::VERSION
    gem.summary = %Q{A tool to ease the creation of scripting language bindings for a C++ library.}
    gem.description = %Q{This is a tool to ease the creation of scripting language bindings for a C++ library.
    It is currently developed to crete the OpenCV bindings for Lua in Rubyk (http://rubyk.org). The generator uses the xml output from Doxygen to avoid parsing C++ code by itself.}
    gem.email = "gaspard@teti.ch"
    gem.homepage = "http://rubyk.org/en/project311.html"
    gem.authors = ["Gaspard Bucher"]
    gem.add_development_dependency "shoulda", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Dub #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
