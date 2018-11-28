require 'stringio'
require 'tempfile'

module Nitra
  module Workers
    class Worker
      class << self

        @@worker_classes = {}

        def inherited(klass)
          @@worker_classes[klass.framework_name] = klass
        end

        def worker_classes
          @@worker_classes
        end

        ##
        # Return the framework name of this worker
        #
        def framework_name
          self.name.split("::").last.downcase
        end

        def files(patterns)
          Dir[*patterns].sort_by {|f| File.size(f)}.reverse
        end
      end

      class RetryException < Exception; end


      attr_reader :runner_id, :worker_number, :configuration, :channel, :io

      def initialize(runner_id, worker_number, configuration)
        @runner_id = runner_id
        @worker_number = worker_number
        @configuration = configuration
        @forked_worker_pid = nil

        ENV["TEST_ENV_NUMBER"] = worker_number.to_s

        # Frameworks don't like it when you change the IO between invocations.
        # So we make one object and flush it after every invocation.
        @io = StringIO.new
      end


      def fork_and_run
        client, server = Nitra::Channel.pipe

        pid = fork do
          # This is important. We don't want anything bubbling up to the master that we didn't send there.
          # We reopen later to get the output from the framework run.
          $stdout.reopen('/dev/null', 'a')
          $stderr.reopen('/dev/null', 'a')

          trap("USR1") { interrupt_forked_worker_and_exit }

          server.close
          @channel = client
          run
        end

        client.close

        [pid, server]
      end

      protected
      def load_environment
        raise 'Subclasses must implement this method.'
      end

      def minimal_file
        raise 'Subclasses must implement this method.'
      end

      def run_file(filename, preloading = false)
        raise 'Subclasses must implement this method.'
      end

      def clean_up
        raise 'Subclasses must implement this method.'
      end

      def run
        trap("SIGTERM") do
          channel.write("command" => "error", "process" => "trap", "text" => 'Received SIGTERM', "on" => on)
          Process.kill("SIGKILL", Process.pid)
        end
        trap("SIGINT") do
          channel.write("command" => "error", "process" => "trap", "text" => 'Received SIGINT', "on" => on)
          Process.kill("SIGKILL", Process.pid)
        end

        channel.write("command" => "starting", "framework" => self.class.framework_name, "on" => on)
        connect_to_database
        reset_cache
        preload_framework
        channel.write("command" => "started", "framework" => self.class.framework_name, "on" => on)

        # Loop until our runner passes us a message from the master to tells us we're finished.
        loop do
          debug "Announcing availability"
          channel.write("command" => "next_file", "framework" => self.class.framework_name, "on" => on)
          debug "Waiting for next job"
          data = channel.read
          if data.nil? || data["command"] == "close"
            debug "Channel closed, exiting"
            exit
          elsif data['command'] == "process_file"
            filename = data["filename"].chomp
            process_file(filename)
          end
        end
      rescue => e
        channel.write("command" => "error", "process" => "worker", "text" => "#{e.message}\n#{e.backtrace.join "\n"}", "on" => on)
      end

      def on
        "#{runner_id}:#{worker_number}"
      end

      def preload_framework
        debug "running empty spec/feature to make framework run its initialisation"
        file = Tempfile.new("nitra")
        begin
          load_environment
          file.write(minimal_file)
          file.close

          output = Nitra::Utils.capture_output do
            run_file(file.path, true)
          end

          debug io.string

          channel.write("command" => "stdout", "process" => "preload framework", "text" => output, "on" => on) if !output.empty? && configuration.debug
        ensure
          file.close unless file.closed?
          file.unlink
          io.string = ""
          $stdout.reopen('/dev/null', 'a') # some frameworks close the output streams, which makes the next fork() call fail
          $stderr.reopen('/dev/null', 'a')
        end
        clean_up
      end

      def connect_to_database
        if defined?(Rails)
          Nitra::RailsTooling.connect_to_database
          debug("Connected to database #{ActiveRecord::Base.connection.current_database}")
        end
      end

      def reset_cache
        Nitra::RailsTooling.reset_cache if defined?(Rails)
      end

      ##
      # Process the file, forking before hand.
      #
      # There's two sets of data we're interested in, the output from the test framework, and any other output.
      # 1) We capture the framework's output in the @io object and send that up to the runner in a results message.
      # This happens in the run_x_file methods.
      # 2) Anything else we capture off the stdout/stderr using the pipe and fire off in the stdout message.
      #
      def process_file(filename)
        debug "Starting to process #{filename}"

        stdout_pipe = IO.pipe
        stderr_pipe = IO.pipe
        @forked_worker_pid = fork do
          trap('USR1') { exit! }  # at_exit hooks will be run in the parent.
          $stdout.reopen(stdout_pipe[1])
          $stderr.reopen(stderr_pipe[1])
          $0 = filename

          @attempt = 1
          run_file_and_handle_errors(filename)

          stdout_pipe.each(&:close)
          stderr_pipe.each(&:close)
          exit!  # at_exit hooks will be run in the parent.
        end
        stdout_pipe[1].close
        stderr_pipe[1].close
        stdout_text, stderr_text = read_all_descriptors(stdout_pipe[0], stderr_pipe[0])
        stdout_pipe[0].close
        stderr_pipe[0].close
        Process.wait(@forked_worker_pid) if @forked_worker_pid
        @forked_worker_pid = nil

        channel.write("command" => "stdout", "process" => filename, "text" => stdout_text, "on" => on) if !stdout_text.empty? && configuration.debug
        channel.write("command" => "stderr", "process" => filename, "text" => stderr_text, "on" => on) if !stderr_text.empty?
      end

      def result_and_memory_growth(filename)
        # add the rusage gem to your bundle to get memory stats in your debug output
        rusage_before = Process.rusage if Process.respond_to?(:rusage)
        result = run_file(filename)
        rusage_after = Process.rusage if Process.respond_to?(:rusage)

        if rusage_before && rusage_after
          one_megabyte = RUBY_PLATFORM =~ /darwin/ ? 1024*1024 : 1024 # despite the OS X man page saying this is kilobytes, it's actually bytes
          result["memory_before"] = rusage_before.maxrss/one_megabyte
          result["memory_growth"] = (rusage_after.maxrss - rusage_before.maxrss)/one_megabyte
        end

        result["pid"] = Process.pid
        result
      end

      def run_file_and_handle_errors(filename)
        result = result_and_memory_growth(filename)
        result["failure"] ||= result["failure_count"] > 0
        channel.write result.merge({
          "command"   => "result",
          "framework" => self.class.framework_name,
          "filename"  => filename,
          "on"        => on,
          "text"      => result["failure"] ? io.string : "",
        })

      rescue RetryException
        @attempt += 1
        channel.write({
          "command"   => "retry",
          "framework" => self.class.framework_name,
          "filename"  => filename,
          "on"        => on,
          "failure"   => true,
          "text"      => io.string,
          "attempt"   => @attempt
        })
        clean_up
        retry

      rescue LoadError, Exception => e
        io << "Exception when running #{filename}: #{e.message}\n#{e.backtrace[0..7].join("\n")}"
        channel.write({
          "command"   => "result",
          "framework" => self.class.framework_name,
          "filename"  => filename,
          "on"        => on,
          "failure"   => true,
          "text"      => io.string,
        })
      end

      def clean_up
        io.string = ""
      end

      def read_all_descriptors(*descriptors)
        output = descriptors.collect { "" }
        active = descriptors.collect { true }
        while active.any? do
          descriptors.each_with_index do |fd, index|
            begin
              output[index] << fd.read_nonblock(65536) if active[index]
            rescue IO::WaitReadable
              # no new data on this descriptor yet
            rescue EOFError
              active[index] = false
            end
          end
          IO.select(descriptors)
        end
        output
      end


      ##
      # Interrupts the forked worker cleanly and exits
      #
      def interrupt_forked_worker_and_exit
        Process.kill('USR1', @forked_worker_pid) if @forked_worker_pid
        Process.waitall
        exit
      end

      ##
      # Sends debug data up to the runner.
      #
      def debug(*text)
        if configuration.debug
          channel.write("command" => "debug", "text" => text.join, "on" => on)
        end
      end

      def unique_output_file_for(filename, template_output_file)
        # use the output file passed to nitra as a template to create a unique
        # filename so sequential calls to the worker don't overwrite previously created
        # output file
        extension = Pathname(template_output_file).extname

        # the worker could support running a file with a line number
        if filename.include?(':')
          line_number = filename.partition(':').last
          worker_file_without_extension = Pathname(filename.partition(':').first).sub_ext("_#{line_number}")
        else
          worker_file_without_extension = Pathname(filename).sub_ext('')
        end

        # append the name of the worker file without an extension before the output file's extension
        Pathname(template_output_file).sub_ext("_#{worker_file_without_extension}#{extension}").to_s
      end

      def retry_configured?
        @configuration.exceptions_to_retry || @configuration.tags_to_retry
      end

      def retry_attempts_remaining?
        @attempt && @attempt < @configuration.max_attempts
      end
    end
  end
end
