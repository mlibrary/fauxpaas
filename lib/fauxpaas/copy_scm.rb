require "capistrano/scm/plugin"
require "pathname"

module Fauxpaas
  class CopySCM < ::Capistrano::SCM::Plugin

    # Define any variables needed to configure the plugin.
    # set_if_empty :myvar, "some_value"
    def set_defaults
    end

    # This must define a task (called create_release) by convention
    # that creates the release directory and copies the source code
    # into it.
    def define_tasks
      namespace :fauxpaas do
        task :create_release do
          on release_roles(:all) do
            execute :mkdir, "-p", release_path
            Pathname.new(repo_url).children.each do |path|
              upload! path.to_s, release_path, recursive: true
            end
          end
        end
        task :set_current_revision do
          set :current_revision, "boomparrot"
        end
      end
    end

    def register_hooks
      after "deploy:new_release_path", "fauxpaas:create_release"
      before "deploy:set_current_revision", "fauxpaas:set_current_revision"
    end

  end
end
