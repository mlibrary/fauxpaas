# frozen_string_literal: true

require "fauxpaas/version"
require "fauxpaas/archive_reference"
require "fauxpaas/auth_service"
require "fauxpaas/cap"
require "fauxpaas/cap_runner"
require "fauxpaas/cli"
require "fauxpaas/deploy_config"
require "fauxpaas/file_instance_repo"
require "fauxpaas/file_permissions_repo"
require "fauxpaas/filesystem"
require "fauxpaas/git_runner"
require "fauxpaas/instance"
require "fauxpaas/local_git_resolver"
require "fauxpaas/logged_release"
require "fauxpaas/open3_capture"
require "fauxpaas/policy"
require "fauxpaas/release"
require "fauxpaas/release_signature"
require "fauxpaas/remote_git_resolver"
require "fauxpaas/invoker"

require "logger"
require "pathname"
require "canister"
require "ettin"

# Fake Platform As A Service
module Fauxpaas
  class << self
    attr_reader :config, :env, :settings
    attr_writer :config, :env

    def method_missing(method, *args, &block)
      if config.respond_to?(method)
        config.send(method, *args, &block)
      else
        super(method, *args, &block)
      end
    end

    def root
      @root ||= Pathname.new(__FILE__).dirname.parent
    end

    def env
      @env ||= ENV["FAUXPAAS_ENV"] || ENV["RAILS_ENV"] || "development"
    end

    def reset!
      @settings = nil
      @loaded = false
      @config = nil
    end

    def load_settings!(hash = {})
      @settings = Ettin.for(Ettin.settings_files(root/"config", env))
      @settings.merge!(hash)
    end

    def initialize!
      load_settings! unless @settings
      @config ||= Canister.new.tap do |container|
        container.register(:logger) { Logger.new(STDOUT, level: :info) }
        container.register(:logger) do
          if settings.verbose
            Logger.new(STDOUT, level: :debug)
          else
            Logger.new(STDOUT, level: :info)
          end
        end
        container.register(:system_runner) { Open3Capture.new }
        container.register(:backend_runner) {|c| Fauxpaas::CapRunner.new(c.system_runner) }
        container.register(:filesystem) { Fauxpaas::Filesystem.new }
        container.register(:git_runner) do |c|
          Fauxpaas::GitRunner.new(
            system_runner: c.system_runner,
            fs: c.filesystem,
            local_resolver: Fauxpaas::LocalGitResolver.new(c.system_runner),
            remote_resolver: Fauxpaas::RemoteGitResolver.new(c.system_runner)
          )
        end
        container.register(:instance_repo) do |c|
          Fauxpaas::FileInstanceRepo.new(
            c.instance_root,
            c.releases_root,
            c.filesystem,
            c.git_runner
          )
        end
        container.register(:permissions_repo) do |c|
          Fauxpaas::FilePermissionsRepo.new(c.instance_root)
        end
        container.register(:auth) do |c|
          data = c.permissions_repo.find
          Fauxpaas::AuthService.new(
            all: data.fetch(:all, {}),
            instances: data.fetch(:instances, {}),
            policy_factory: Fauxpaas::Policy
          )
        end

        container.register(:server) { settings.server }
        container.register(:invoker) { Fauxpaas::Invoker.new }
        container.register(:instance_root) { Pathname.new(settings.instance_root).expand_path(Fauxpaas.root) }
        container.register(:releases_root) { Pathname.new(settings.releases_root).expand_path(Fauxpaas.root) }
        container.register(:deployer_env_root) { Pathname.new(settings.deployer_env_root).expand_path(Fauxpaas.root) }
        container.register(:split_token) { settings.split_token.chomp }
      end
    end

  end
end

