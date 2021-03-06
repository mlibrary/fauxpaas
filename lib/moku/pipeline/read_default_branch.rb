# frozen_string_literal: true

require "moku/pipeline/pipeline"

module Moku
  module Pipeline

    # Read and print the default branch
    class ReadDefaultBranch < Pipeline
      register(self)

      def self.handles?(command)
        command.action == :read_default_branch
      end

      def call
        # Avoid calling step because the logger will be used for output,
        # and calling step would make it less clean.
        print_default_branch
      end

      private

      def print_default_branch
        logger.info "Default branch: #{instance.default_branch}"
      end
    end

  end
end
