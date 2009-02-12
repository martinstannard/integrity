require "rake/testtask"
require "rake/clean"
require "rcov/rcovtask"

require File.dirname(__FILE__) + "/lib/integrity"

desc "Run all tests and check test coverage"
task :default => "test:coverage:verify"

desc "Run tests"
task :test => %w(test:units test:acceptance)

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.test_files = FileList["test/unit/*_test.rb"]
  end

  Rake::TestTask.new(:acceptance) do |t|
    t.test_files = FileList["test/acceptance/*_test.rb"]
  end

  desc "Measure test coverage"
  task :coverage => %w(test:coverage:units test:coverage:acceptance)

  namespace :coverage do
    desc "Measure test coverage of unit tests"
    Rcov::RcovTask.new(:units) do |rcov|
      rcov.pattern   = "test/unit/*_test.rb"
      rcov.rcov_opts = %w(--html --aggregate .aggregated_coverage_report)
      rcov.rcov_opts << ENV["RCOV_OPTS"] if ENV["RCOV_OPTS"]
    end

    desc "Measure test coverage of acceptance tests"
    Rcov::RcovTask.new(:acceptance) do |rcov|
      rcov.pattern   = "test/acceptance/*_test.rb"
      rcov.rcov_opts = %w(--html --aggregate .aggregated_coverage_report)
      rcov.rcov_opts << ENV["RCOV_OPTS"] if ENV["RCOV_OPTS"]
    end

    desc "Verify test coverage"
    task :verify => "test:coverage" do
      File.read("coverage/index.html") =~ /<tt class='coverage_total'>\s*(\d+\.\d+)%\s*<\/tt>/
      coverage = $1.to_f

      puts
      if coverage == 100
        puts "\e[32m100% coverage! Awesome!\e[0m"
      else
        puts "\e[31mOnly #{coverage}% code coverage. You can do better ;)\e[0m"
      end
    end
  end

  desc "Install all gems on which the tests depend on"
  task :install_dependencies do
    system 'gem install redgreen rr mocha ruby-debug dm-sweatshop webrat'
    system 'gem install -s http://gems.github.com jeremymcanally-context jeremymcanally-matchy jeremymcanally-pending foca-storyteller'
  end
end

namespace :db do
  desc "Setup connection."
  task :connect do
    config = File.expand_path(ENV['CONFIG']) if ENV['CONFIG']
    config = Integrity.root / 'config.yml' if File.exists?(Integrity.root / 'config.yml')
    Integrity.new(config)
  end

  desc "Automigrate the database"
  task :migrate => :connect do
    require "project"
    require "build"
    require "notifier"
    DataMapper.auto_migrate!
  end
end

directory "dist/"
CLOBBER.include("dist")

def package(ext="")
  "dist/integrity-#{Integrity.version}" + ext
end

desc "Build and install as local gem"
task :install => package(".gem") do
  sh "gem install #{package(".gem")}"
end

desc "Release a new version"
task :release => ["jeweler:release", "rubyforge:publish", "rubyforge:push"]

namespace :package do
  desc "Build packages"
  task :build => %w[.gem .tar.gz].map { |ext| package(ext) } << :"package:changelog"

  task :changelog => ["dist/git-changelog.py"] do
    sh "python dist/git-changelog.py"
    sh "git add ChangeLog"
    sh 'git commit -m "Regenerated ChangeLog"'
  end

  file package(".gem") => %w[dist/ integrity.gemspec] do |f|
    sh "gem build integrity.gemspec"
    mv File.basename(f.name), f.name
  end

  file package(".tar.gz") => %w[dist/] do |f|
    sh <<-SH
      git archive \
        --prefix=integrity-#{Integrity.version}/ \
        --format=tar \
        HEAD | gzip > #{f.name}
    SH
  end

  file "dist/git-changelog.py" => %w[dist/] do
    sh "cd dist && wget http://gist.github.com/raw/62837/bc6d2c6102933c3eac5fa33afd3effd7ab97edb7/git-changelog.py"
  end
end

namespace :rubyforge do
  desc "Publish gem and tarball to rubyforge"
  task :publish => ["package:build"] do |t|
    sh <<-end
      rubyforge add_release integrity integrity #{Integrity.version} #{package('.gem')} &&
      rubyforge add_file    integrity integrity #{Integrity.version} #{package('.tar.gz')}
    end
  end

  desc "Push to gitosis@rubyforge.org:integrity.git"
  task :push do
    sh "git push gitosis@rubyforge.org:integrity.git master"
  end
end

begin
  require "jeweler"

  namespace :jeweler do
    Jeweler::Tasks.new do |s|
      files  = `git ls-files`.split("\n").reject {|f| f =~ %r(^test/acceptance) || f =~ %r(^test/unit) || f =~ /^\.git/ }

      s.name                 = 'integrity'
      s.summary              = 'The easy and fun Continuous Integration server'
      s.description          = 'Your Friendly Continuous Integration server. Easy, fun and painless!'
      s.homepage             = 'http://integrityapp.com'
      s.rubyforge_project    = 'integrity'
      s.email                = 'contacto@nicolassanguinetti.info'
      s.authors              = ['Nicolás Sanguinetti', 'Simon Rozet']
      s.files                = files
      s.executables          = ['integrity']
      s.post_install_message = 'Run `integrity help` for information on how to setup Integrity.'

      s.add_dependency 'sinatra', ['>= 0.9.0.3']
      s.add_dependency 'haml',    ['>= 2.0.0']
      s.add_dependency 'dm-core', ['>= 0.9.5']
      s.add_dependency 'dm-validations', ['>= 0.9.5']
      s.add_dependency 'dm-types', ['>= 0.9.5']
      s.add_dependency 'dm-timestamps', ['>= 0.9.5']
      s.add_dependency 'dm-aggregates', ['>= 0.9.5']
      s.add_dependency 'dm-migrations', ['>= 0.9.5']
      s.add_dependency 'data_objects', ['>= 0.9.5']
      s.add_dependency 'do_sqlite3', ['>= 0.9.5']
      s.add_dependency 'json'
      s.add_dependency 'foca-sinatra-diddies', ['>= 0.0.2']
      s.add_dependency 'thor'
      s.add_dependency 'uuidtools' # required by dm-types
      s.add_dependency 'bcrypt-ruby' # required by dm-types
    end
  end
rescue LoadError
end

