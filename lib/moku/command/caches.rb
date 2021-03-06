# frozen_string_literal: true

require "moku"
require "moku/command/command"

module Moku
  module Command

    # Show the cached releases
    class Caches < Command
      def initialize(instance_name:, user:, long: false)
        super(instance_name: instance_name, user: user)
        @long = long
      end

      attr_reader :long

      def action
        :caches
      end

    end

  end
end
