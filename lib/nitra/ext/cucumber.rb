require 'cucumber/runtime'

module Cucumber
  # Reloading support files is bad for us. Ideally we'd subclass but since
  # Cucumber's internals insist on using the new keyword
  # everywhere, we have to monkeypatch it out

  CUCUMBER_3 = ::Cucumber::VERSION.chomp.split(/\./).first.to_i >= 3

  if CUCUMBER_3
    require 'cucumber/glue/registry_and_more'

    module Glue
      class RegistryAndMore
        def load_code_file(code_file)
          return unless File.extname(code_file) == '.rb'

          require File.expand_path(code_file) # This will cause self.add_step_definition, self.add_hook, and self.define_parameter_type to be called from Glue::Dsl
        end
      end
    end
  else
    require 'cucumber/rb_support/rb_language'

    module RbSupport
      class RbLanguage
        def load_code_file(code_file)
          require File.expand_path(code_file)
        end
      end
    end
  end

  class ResetableRuntime < Runtime
    # Cucumber lacks a reset hook like the one Rspec has so we need to patch one in...
    # Call this after configure so that the correct configuration is used to create the result set.
    def reset
      if CUCUMBER_3
        @fail_fast_report = nil
        @features = nil
        @filespecs = nil
        @formatters = nil
        @report = nil
        @results = nil
        @summary_report = nil

        @results =
          if defined?(Formatter::LegacyApi::Results) && !CUCUMBER_3
            Formatter::LegacyApi::Results.new
          end
      else
        @results = Results.new(@configuration)
        @loader = nil
      end
    end

    if CUCUMBER_3
      def run!
        @events = []

        @configuration.on_event(:test_case_finished) do |event|
          @events << event
        end

        super
      end

      def exception_for(scenario)
        @events.find { |event| event.test_case == scenario }&.result&.exception
      end
    end

    def failure?
      if defined?(super)
        super
      else
        results.failure?
      end
    end

    def scenarios(*args)
      if CUCUMBER_3
        if args.empty?
          @events.map(&:test_case)
        elsif args == [:failed]
          @events.find_all { |event| event.result.failed? }.map(&:test_case)
        else
          raise "Cannot handle args #{args}"
        end
      elsif defined?(Formatter::LegacyApi::Results)
        report.runtime.find { |r| r.is_a? Formatter::LegacyApi::Adapter }.results.scenarios(*args)
      else
        super
      end
    end
  end
end
