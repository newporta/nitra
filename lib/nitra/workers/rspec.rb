require 'pathname'

module Nitra::Workers
  class Rspec < Worker
    def self.filename_match?(filename)
      filename =~ /_spec\.rb/
    end

    def initialize(runner_id, worker_number, configuration)
      super(runner_id, worker_number, configuration)
    end

    def load_environment
      require 'rspec'
      RSpec::Core::Runner.disable_autorun!
      RSpec.configuration.output_stream = io
    end

    def minimal_file
      <<-EOS
      require 'spec_helper'
      RSpec.describe('nitra preloading') do
        it('preloads the fixtures') do
          expect(1).to eq(1)
        end
      end
      EOS
    end

    ##
    # Run an rspec file.
    #
    def run_file(filename, preloading = false)
      runner, will_split_file = runner_for(filename, preloading)
      failure = runner.run(io, io).to_i != 0

      if will_split_file
        {
          "test_count"    => 0,
          "failure_count" => 0,
          "failure"       => failure,
          "parts_to_run"  => runnable_parts(runner),
        }
      else
        raise RetryException if failure && retry_run?(runner)

        if m = io.string.match(/(\d+) examples?, (\d+) failure/)
          test_count = m[1].to_i
          failure_count = m[2].to_i
        else
          test_count = failure_count = 0
        end

        {
          "failure"       => failure,
          "test_count"    => test_count,
          "failure_count" => failure_count,
        }
      end
    end

    def runner_for(filename, preloading)
      split_tests = !preloading && splittable?(filename)

      args = []

      if split_tests
        args << '--dry-run'
      elsif configuration.rspec_formatter && !preloading
        args << '--format'
        args << 'progress'
        args << '--format'
        args << configuration.rspec_formatter

        if configuration.rspec_out
          args << '--out'

          args << unique_output_file_for(filename, configuration.rspec_out)
        end
      end

      args << filename

      result =
        if RSpec::Core::const_defined?(:CommandLine) && RSpec::Core::Version::STRING < "2.99"
          RSpec::Core::CommandLine.new(args)
        else
          options = RSpec::Core::ConfigurationOptions.new(args)
          options.parse_options if options.respond_to?(:parse_options) # only for 2.99
          RSpec::Core::Runner.new(options)
        end

      [result, split_tests]
    end

    def clean_up
      super

      if RSpec::Core::Version::STRING < "3.2"
        # Rspec.reset in 2.6 didn't destroy your rspec_rails fixture loading, we can't use it anymore for it's intended purpose.
        # This means our world object will be slightly polluted by the preload_framework code, but that's a small price to pay
        # to upgrade.
        #
        # RSpec.reset
        #
        RSpec.instance_variable_set(:@world, nil)

        # reset the reporter so we don't end up with two when we reuse the Configuration
        RSpec.configuration.reset
      else
        RSpec.clear_examples
      end
    end

    def runnable_parts(runner)
      runner.world.all_examples.map(&:metadata).map do |metadata|
        "#{metadata[:rerun_file_path]}[#{metadata[:scoped_id]}]".sub(/^\.\//, '')
      end
    end

    def retry_run?(runner)
      return false unless retry_configured?
      return false unless retry_attempts_remaining?

      match_retry_exception? || match_retry_tag?(runner)
    end

    def splittable?(filename)
      return false if !configuration.split_rspec_files || already_split?(filename)

      @configuration.split_rspec_files_regex.nil? || filename =~ @configuration.split_rspec_files_regex
    end

    def match_retry_exception?
      @configuration.exceptions_to_retry && io.string =~ @configuration.exceptions_to_retry
    end

    def match_retry_tag?(runner)
      @configuration.tags_to_retry && (@configuration.tags_to_retry & runner_tags(runner)).any?
    end

    def runner_tags(runner)
      (runner.world.all_examples.map(&:metadata).flat_map(&:keys) - STANDARD_METADATA_KEYS).map(&:to_s)
    end

    STANDARD_METADATA_KEYS = %i[
      absolute_file_path
      block
      caller
      described_class
      description
      description_args
      example_group
      execution_result
      file_path
      full_description
      last_run_status
      line_number
      location
      rerun_file_path
      scoped_id
      shared_group_inclusion_backtrace
    ].freeze
  end
end
