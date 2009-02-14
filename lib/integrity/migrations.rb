require "dm-migrations"
require "migration_runner"

module Integrity
  def self.migrate(direction, level=nil)
    setup_initial_migration if pre_migrations?

    case direction
      when "up"   then Integrity::Migrations.migrate_up!(level)
      when "down" then Integrity::Migrations.migrate_down!(level)
      else raise ArgumentError, "DIRECTION must be either up or down"
    end
  end

  def self.setup_initial_migration
    database_adapter.execute %q(CREATE TABLE "migration_info" ("migration_name" VARCHAR(255));)
    database_adapter.execute %q(INSERT INTO "migration_info" ("migration_name") VALUES ("initial"))
  end

  def self.pre_migrations?
    !table_exists?("migration_info") &&
      ( table_exists?("integrity_projects") &&
        table_exists?("integrity_builds")   &&
        table_exists?("integrity_notifiers") )
  end

  def self.table_exists?(table_name)
    database_adapter.storage_exists?(table_name)
  end

  def self.database_adapter
    DataMapper.repository(:default).adapter
  end

  module Migrations
    # This is what is actually happening:
    # include DataMapper::MigrationRunner

    include DataMapper::Types

    migration 1, :initial, :verbose => false do
      up do
        create_table :integrity_projects do
          column :id,          Integer,  :serial => true
          column :name,        String,   :nullable => false
          column :permalink,   String
          column :uri,         URI,      :nullable => false
          column :branch,      String,   :nullable => false, :default => "master"
          column :command,     String,   :nullable => false, :default => "rake"
          column :public,      Boolean,                      :default  => true
          column :building,    Boolean,                      :default  => false
          column :created_at,  DateTime
          column :updated_at,  DateTime

          column :build_id,    Integer
          column :notifier_id, Integer
        end

        create_table :integrity_builds do
          column :id,                Integer,  :serial => true
          column :output,            Text,     :nullable => false, :default => ""
          column :successful,        Boolean,  :nullable => false, :default => false
          column :commit_identifier, String,   :nullable => false
          column :commit_metadata,   Yaml,     :nullable => false
          column :created_at,        DateTime
          column :updated_at,        DateTime

          column :project_id,        Integer
        end

        create_table :integrity_notifiers do
          column :id,         Integer, :serial => true
          column :name,       String,  :nullable => false
          column :config,     Yaml,    :nullable => false

          column :project_id, Integer
        end
      end

      down do
        drop_table :integrity_notifiers
        drop_table :integrity_projects
        drop_table :integrity_builds
      end
    end

    migration 2, :add_commits, :verbose => false do
      up do
        class ::Integrity::Build
          property :commit_identifier, String
          property :commit_metadata,   Yaml,   :lazy => false
          property :project_id,        Integer
        end

        create_table :integrity_commits do
          column :id,           Integer,  :serial => true
          column :identifier,   String,   :nullable => false
          column :message,      String,   :nullable => false, :length => 255
          column :author,       String,   :nullable => false, :length => 255
          column :committed_at, DateTime, :nullable => false
          column :created_at,  DateTime
          column :updated_at,  DateTime

          column :project_id,   Integer
        end

        modify_table :integrity_builds do
          add_column :commit_id,    Integer
          add_column :started_at,   DateTime
          add_column :completed_at, DateTime
        end

        # Die, orphans, die
        Build.all(:project_id => nil).destroy!

        # sqlite hodgepockery
        all_builds = Build.all.each {|b| b.freeze }
        drop_table :integrity_builds
        create_table :integrity_builds do
          column :id,           Integer, :serial => true
          column :started_at,   DateTime
          column :completed_at, DateTime
          column :successful,   Boolean
          column :output,       Text,    :nullable => false, :default => ""
          column :created_at,   DateTime
          column :updated_at,   DateTime

          column :commit_id,    Integer
        end

        all_builds.each do |build|
          commit = Commit.first(:identifier => build.commit_identifier)

          if commit.nil?
            commit = Commit.create(:identifier   => build.commit_identifier,
                                   :message      => build.commit_metadata[:message],
                                   :author       => build.commit_metadata[:author],
                                   :committed_at => build.commit_metadata[:date],
                                   :project_id   => build.project_id)
          end

          Build.create(:commit_id    => commit.id,
                       :started_at   => build.created_at,
                       :completed_at => build.updated_at,
                       :successful   => build.successful,
                       :output       => build.output)
        end
      end

      down do
        modify_table :integrity_builds do
          add_column :commit_identifier, String, :nullable => false
          add_column :commit_metadata,   Yaml,   :nullable => false
          add_column :project_id,        Integer
        end

        # sqlite hodgepockery
        all_builds = Build.all.map {|b| b.freeze }
        drop_table :integrity_builds
        create_table :integrity_builds do
          column :id,                Integer,  :serial => true
          column :output,            Text,     :nullable => false, :default => ""
          column :successful,        Boolean,  :nullable => false, :default => false
          column :commit_identifier, String,   :nullable => false
          column :commit_metadata,   Yaml,     :nullable => false
          column :created_at,        DateTime
          column :updated_at,        DateTime
          column :project_id,        Integer
        end

        all_builds.each do |build|
          Build.create(:project_id => build.commit.project_id,
                       :output => build.output,
                       :successful => build.successful,
                       :commit_identifier => build.commit.identifier,
                       :commit_metadata => {
            :message => build.commit.message,
            :author => build.commit.author.full,
            :date => commit.committed_at
          }.to_yaml)
        end

        drop_table :commits
      end
    end
  end
end
