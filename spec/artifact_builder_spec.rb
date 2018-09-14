# frozen_string_literal: true

require_relative "spec_helper"
require "fauxpaas/artifact_builder"
require "pathname"

module Fauxpaas
  class FakeLazyDir
    attr_reader :path
    def initialize(path)
      @path = path
    end

    def cp(base)
      self.class.new(base)
    end

    def write
      self
    end
  end

  class TestArtifact
    attr_reader :path
    def initialize(path)
      @path = path
    end
  end

  # require "fauxpaas/artifact_builder"
  RSpec.describe ArtifactBuilder do
    let(:ref_repo) { double(:ref_repo) }
    let(:builder) { described_class.new(ref_repo: ref_repo) }
    let(:builder) do
      described_class.new(
        factory: TestArtifact,
        ref_repo: ref_repo,
        runner: double(:runner)
      )
    end

    describe "#build" do
      let(:tmpdir) { Pathname.new "/tmp/dir" }
      let(:source) { double(:source) }
      let(:shared) { double(:shared) }
      let(:deploy) { double(:deploy) }
      let(:unshared) { double(:unshared) }
      let(:signature) { double(:signature, shared: shared, unshared: unshared, source: source) }

      before(:each) do
        allow(Dir).to receive(:mktmpdir).and_return(tmpdir.to_s)
        allow(ref_repo).to receive(:resolve).with(source)
          .and_return(FakeLazyDir.new("/some_source"))
        allow(ref_repo).to receive(:resolve).with(shared)
          .and_return(FakeLazyDir.new("/some_shared"))
        allow(ref_repo).to receive(:resolve).with(unshared)
          .and_return(FakeLazyDir.new("/some_unshared"))
      end

      it "constructs artifacts" do
        expect(builder.build(signature)).not_to be_nil
      end

      it "returns the temporary directory with the artifacts" do
        expect(builder.build(signature).path).to eq(tmpdir)
      end

      [:source, :shared, :unshared].each do |attr|
        it "resolves the #{attr} repository" do
          expect(ref_repo).to receive(:resolve).with(send(attr))
            .and_return(FakeLazyDir.new("/some_#{attr}"))

          builder.build(signature)
        end
      end
    end
  end
end
