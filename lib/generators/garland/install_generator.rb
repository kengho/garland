# based on
# https://github.com/huacnlee/rails-settings-cached/blob/master/lib/generators/settings/install_generator.rb
# by Jason "huacnlee" Lee
require "rails/generators"
require "rails/generators/migration"

module Garland
  class InstallGenerator < Rails::Generators::Base
    desc 'Generate Garland files.'
    include Rails::Generators::Migration
    source_root File.expand_path("../templates", __FILE__)

    @@migrations = false

    def self.next_migration_number(dirname) #:nodoc:
      if ActiveRecord::Base.timestamped_migrations
        if @@migrations
          (current_migration_number(dirname) + 1)
        else
          @@migrations = true
          Time.now.utc.strftime('%Y%m%d%H%M%S')
        end
      else
        format '%.3d', current_migration_number(dirname) + 1
      end
    end

    def install_garland
      migration_template "migration.rb", 'db/migrate/create_garlands.rb'
    end
  end
end
