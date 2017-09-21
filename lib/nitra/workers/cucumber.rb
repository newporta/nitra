module Nitra::Workers
  class Cucumber < Worker
    def self.filename_match?(filename)
      filename =~ /\.feature/
    end

    def initialize(runner_id, worker_number, configuration)
      super(runner_id, worker_number, configuration)
    end

    def load_environment
      require 'cucumber'
      require 'nitra/ext/cucumber'
    end

    def minimal_file
      <<-EOS
      @nitra_preloading
      Feature: cucumber preloading
        Scenario: a fake scenario
      EOS
    end

    def cuke_runtime
      @cuke_runtime ||= ::Cucumber::ResetableRuntime.new  # This runtime gets reused, this is important as it's the part that loads the steps...
    end

    ##
    # Run a Cucumber file.
    #
    def run_file(filename, preloading = false)
      args = []

      args << '--no-color'
      args << '--require'
      args << 'features'

      if configuration.split_files && !preloading && !filename.include?(':')
        args << '--dry-run'
        args << filename

        run_with_arguments(args)

        {
          "test_count"    => 0,
          "failure_count" => 0,
          "failure"       => false,
          "parts_to_run"  => runnable_parts,
        }
      else
        if configuration.cucumber_formatter && !preloading
          args << '--format'
          args << 'pretty'
          args << '--format'
          args << configuration.cucumber_formatter

          if configuration.cucumber_out
            args << '--out'
            args << unique_output_file_for(filename, configuration.cucumber_out)
          end
        end

        args << filename

        run_with_arguments(args)

        if cuke_runtime.failure? && @configuration.exceptions_to_retry && @attempt && @attempt < @configuration.max_attempts &&
           cuke_runtime.results.scenarios(:failed).any? {|scenario| scenario.exception.to_s =~ @configuration.exceptions_to_retry || scenario.exception.class.to_s =~ @configuration.exceptions_to_retry}
          raise RetryException
        end

        if m = io.string.match(/(\d+) scenarios?.+$/)
          test_count = m[1].to_i
          if m = io.string.match(/\d+ scenarios? \(.*(\d+) [failed|undefined].*\)/)
            failure_count = m[1].to_i
          else
            failure_count = 0
          end
        else
          test_count = failure_count = 0
        end

        {
          "test_count"    => test_count,
          "failure_count" => failure_count,
          "failure"       => cuke_runtime.failure?,
        }
      end
    end

    def clean_up
      super

      cuke_runtime.reset
    end

    def run_with_arguments(args)
      cuke_config = ::Cucumber::Cli::Configuration.new(io, io)
      cuke_config.parse!(args)
      cuke_runtime.configure(cuke_config)
      cuke_runtime.run!
    end

    def runnable_parts
      scenarios, example_rows = cuke_runtime.scenarios.partition { |scenario| scenario.respond_to?(:location) }
      outlines = example_rows.map(&:scenario_outline)

      (outlines + scenarios).map { |runnable| "#{runnable.location.file}:#{runnable.location.line}" }.uniq
    end
  end
end
