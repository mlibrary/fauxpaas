# frozen_string_literal: true

require "moku"
require "moku/command/command"
require "moku/pipeline/init"
require "json"
require "ostruct"

module Moku
  module Command

    # Provision a new instance
    class Init < Command
      def initialize(instance_name:, user:, json:, rails:)
        super(instance_name: instance_name, user: user)
        @json = json
        @rails = rails
      end

      def action
        :init
      end

      def call
        Pipeline::Init.new(
          instance: instance,
          first_run: first_run?,
          content: content,
          rails: rails?
        ).call
      end

      private

      def content
        @content ||= JSON.parse(@json)
      end

      def rails?
        @rails
      end

      # Return an entity matching the 'world' permission
      # if the instance does not already exist.
      def instance
        super
      rescue ArgumentError
        OpenStruct.new(name: "world")
      end

      # Has this command been run successfully before?
      def first_run?
        instance.name == "world"
      end

    end

  end
end
