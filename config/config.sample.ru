#!/usr/bin/env ruby
# If you want to add any notifiers, install the gems and then require them here
# For example, to enable the Email notifier: install the gem (from github:
#
#   sudo gem install -s http://gems.github.com foca-integrity-email
#
# And then uncomment the following line:
#
# require "notifier/email"

require "integrity/app"

Integrity.new(File.dirname(__FILE__) + "/config.yml")

Integrity::App.set :environment, ENV["RACK_ENV"] || :production
Integrity::App.set :public,      Integrity.root / "public"
Integrity::App.set :views,       Integrity.root / "views"
Integrity::App.set :port,        8910

run Integrity::App.new
