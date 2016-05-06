require "resque"

require "config_options"
require "jobs/completed_file_review_job"
require "haml_lint"
require "source_file"
require "haml_lint/runner"

class HamlReviewJob
  @queue = :haml_review

  # This job receives the following arguments
  # - filename
  # - content
  # - config
  # - pull_request_number (pass-through)
  # - commit_sha (pass-through)
  # - patch (pass-through)
  def self.perform(attributes)
    config = config_for(attributes: attributes)
    file = file_for(attributes: attributes)
    violations = violations_for(file: file, config: config)

    completed_file_review(
      file: file,
      attributes: attributes,
      violations: violations,
    )
  end

  def self.completed_file_review(file:, attributes:, violations:)
    Resque.enqueue(
      CompletedFileReviewJob,
      filename: file.path,
      commit_sha: attributes.fetch("commit_sha"),
      pull_request_number: attributes.fetch("pull_request_number"),
      patch: attributes.fetch("patch"),
      violations: violations,
    )
  end

  def self.violations_for(file:, config:)
    haml_lint_runner = HamlLint::Runner.new(config)
    haml_lint_runner.violations_for(file)
  end

  def self.file_for(attributes:)
    SourceFile.new(
      attributes.fetch("filename"),
      attributes.fetch("content"),
    )
  end

  def self.config_for(attributes:)
    ConfigOptions.new(attributes["config"], "haml.yml")
  end
end