# frozen_string_literal: true

require "pathname"

module Fauxpaas
  class << self
    def root
      @root ||= Pathname.new(__FILE__).dirname.parent.parent.parent
    end

    def instance_root
      @instance_root ||= root/"data"/"instances"
    end

    def releases_root
      @releases_root ||= root/"releases"
    end

    def deployer_env_root
      @deployer_env_root ||= root/"deploy"/"capfiles"
    end
  end
end
