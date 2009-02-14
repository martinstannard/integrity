require File.dirname(__FILE__) + "/../lib/integrity"

begin
  require "test/unit"
  require "redgreen"
  require "context"
  require "storyteller"
  require "pending"
  require "matchy"
  require "rr"
  require "mocha"
  require "ruby-debug"
rescue LoadError
  puts "You're missing some gems required to run the tests."
  puts "Please run `rake test:install_dependencies`"
  puts "You'll probably need to run that command as root or with sudo."
  puts
  puts "Thanks :)"
  puts

  exit 1
end

require File.dirname(__FILE__) / "helpers" / "expectations"
require File.dirname(__FILE__) / "helpers" / "fixtures"

module TestHelper
  def ignore_logs!
    stub(Integrity).log { nil }
  end
end

class Test::Unit::TestCase
  class << self
    alias_method :specify, :test
  end

  include RR::Adapters::TestUnit
  include Integrity
  include TestHelper

  before(:all) do
    DataMapper.setup(:default, "sqlite3::memory:")
  end

  before(:each) do
    DataMapper.auto_migrate!
    repository(:default) do
      transaction = DataMapper::Transaction.new(repository)
      transaction.begin
      repository.adapter.push_transaction(transaction)
    end
  end

  after(:each) do
    repository(:default) do
      while repository.adapter.current_transaction
        repository.adapter.current_transaction.rollback
        repository.adapter.pop_transaction
      end
    end
  end
end
