def dump_load_path
  puts $LOAD_PATH.join("\n")
  found = nil
  $LOAD_PATH.each do |path|
    if File.exists?(File.join(path,"rspec"))
      puts "Found rspec in #{path}"
      if File.exists?(File.join(path,"rspec","core"))
        puts "Found core"
        if File.exists?(File.join(path,"rspec","core","rake_task"))
          puts "Found rake_task"
          found = path
        else
          puts "!! no rake_task"
        end
      else
        puts "!!! no core"
      end
    end
  end
  if found.nil?
    puts "Didn't find rspec/core/rake_task anywhere"
  else
    puts "Found in #{path}"
  end
end
require 'bundler'
require 'rake/clean'

require 'rake/testtask'

gem 'rdoc' # we need the installed RDoc gem, not the system one
require 'rdoc/task'

include Rake::DSL

Bundler::GemHelper.install_tasks


task :test => :build
task :release => :test

task :build => :tangle
task :build => :weave

lmd_files = Rake::FileList['src/*.lmd']
outputs = lmd_files.pathmap('%{^src,bin}X')
docs = lmd_files.pathmap('%{^src,doc}X.md')

task :tangle => outputs
task :weave => docs

lmd_files.zip(outputs, docs).each do |lmd_file, output, doc|
  directory output_dir = output.pathmap('%d')
  directory doc_dir = doc.pathmap('%d')
  file output => [output_dir, lmd_file] do
    sh "ruby bin/lmt --file #{lmd_file} --output #{output}"
  end
  file doc => [doc_dir, lmd_file] do
    sh "ruby bin/lmw --file #{lmd_file} --output #{doc}"
  end
end

Rake::TestTask.new do |t|
  t.pattern = 'test/tc_*.rb'
end

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  
  rd.rdoc_files.include("README.rdoc","lib/**/*.rb","bin/**/*")
end

task :default => [:test]

