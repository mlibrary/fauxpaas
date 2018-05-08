# frozen_string_literal: true

require "fauxpaas"
require "tmpdir"
require "pathname"
require "open3"

module Fauxpaas

  RSpec.describe "integration tests", integration: true do
    describe "deploy" do
      RSpec.shared_context "deploy setup" do |instance_name|
        before(:all) do
          @root = Pathname.new(Dir.tmpdir)/"fauxpaas"/"sandbox"/instance_name
          `mkdir -p #{@root}`
          Fauxpaas.reset!
          Fauxpaas.initialize!
          Fauxpaas.config.tap do |config|
            config.register(:instance_root) do
              Pathname.new("spec/fixtures/integration/instances").expand_path(Fauxpaas.root)
            end
            config.register(:releases_root) do
              Pathname.new("spec/fixtures/integration/releases").expand_path(Fauxpaas.root)
            end
            config.register(:deployer_env_root) do
              Pathname.new("spec/fixtures/integration/capfiles").expand_path(Fauxpaas.root)
            end
            config.register(:logger) { Logger.new(StringIO.new, level: :info) }
          end
          Fauxpaas.invoker.add_command(
            DeployCommand.new(
              user: ENV["USER"],
              instance_name: instance_name,
              reference: nil
            )
          )
        end
        after(:all) do
          `rm -rf #{@root}`
          `git discard spec/fixtures/integration/instances`
          `git discard spec/fixtures/integration/releases`
        end
        let(:root) { @root }
        let(:current_dir) { root/"current" }
      end

      # Expects
      # let(:gem) { some gem name }
      # let(:source) { some source file relative path }
      RSpec.shared_examples "a successful deploy" do
        it "the 'releases' dir exists" do
          expect((root/"releases").exist?).to be true
        end
        it "the 'current' dir exists" do
          expect(current_dir.exist?).to be true
        end
        it "installs unshared files" do
          expect(File.read(current_dir/"some"/"dev"/"file.txt")).to eql("with some dev contents\n")
        end
        it "sets unshared files to be readable only by the application user" do
          file = current_dir/"some"/"dev"/"file.txt"
          expect(file.world_readable?).to be_falsey
          expect(file.world_writable?).to be_falsey
        end
        it "installs shared files" do
          expect(File.read(current_dir/"some"/"shared"/"file.txt"))
            .to eql("with some shared contents\n")
        end
        it "sets shared files to be readable only by the application user" do
          file = current_dir/"some"/"shared"/"file.txt"
          expect(file.world_readable?).to be_falsey
          expect(file.world_writable?).to be_falsey
        end
        it "runs after_build commands" do
          expect((current_dir/"eureka_2.txt").exist?).to be true
          expect(File.read(current_dir/"eureka_1.txt")).to eql("eureka!\n")
        end
        it "installs the gems" do
          # The expect {}-to-output syntax didn't like this test
          Dir.chdir(current_dir) do
            expect(`BUNDLE_GEMFILE=#{current_dir/"Gemfile"} bundle list`).to match(/#{gem}/)
          end
        end
        it "installs the source files" do
          expect((current_dir/source).exist?)
            .to be true
        end
      end

      context "without rails" do
        include_context "deploy setup", "test-norails"
        let(:gem) { "pry" }
        let(:source) { Pathname.new("some_source_file.txt") }

        include_examples "a successful deploy"
      end

      context "with rails" do
        include_context "deploy setup", "test-rails"
        let(:gem) { "rails" }
        let(:source) { Pathname.new("config/environment.rb") }

        include_examples "a successful deploy"

        it "runs the migrations" do
          expect(`sqlite3 #{current_dir/"db"/"production.sqlite3"} ".schema posts"`.chomp)
            .to match(/CREATE TABLE (IF NOT EXISTS )?"posts"/)
          expect(`sqlite3 #{current_dir/"db"/"production.sqlite3"} ".schema things"`.chomp)
            .to match(/CREATE TABLE (IF NOT EXISTS )?"things"/)
        end

        it "installs a working project" do
          _, _, status = Open3.capture3(
            "BUNDLE_GEMFILE=#{current_dir/"Gemfile"} bundle exec rails runner 'Post.new.valid?'"
          )
          expect(status.success?).to be true
        end
      end
    end
  end
end