require_relative '../spec_helper.rb'
require_relative '../../lib/nitra/command_line'

describe Nitra::CommandLine do

  let(:config){ m = MiniTest::Mock.new }

  describe "option parsing" do
    describe "-c" do
      it "sets process count" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:set_process_count, nil, [2])
        Nitra::CommandLine.new(config, ['-c','2'])
        config.verify
      end
    end

    describe "--cucumber" do
      it "adds cucumber to framework" do
        config.expect(:add_framework, nil, ['cucumber', ["features/**/*.feature"]])
        config.expect(:frameworks, {'cucumber' => ["features/**/*.feature"]})
        Nitra::CommandLine.new(config, ['--cucumber'])
        config.verify
      end
    end

    describe "--debug" do
      it "adds debug flag" do
        config.expect(:debug=, nil, [true])
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        Nitra::CommandLine.new(config, ['--debug'])
        config.verify
      end
    end

    describe "-p" do
      it "adds print failure flag" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:print_failures=, nil, [true])
        Nitra::CommandLine.new(config, ['-p'])
        config.verify
      end
    end

    describe "-q" do
      it "adds quiet flag" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:quiet=, nil, [true])
        Nitra::CommandLine.new(config, ['-q'])
        config.verify
      end
    end

    describe "-e" do
      it "sets the rails environment" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:environment=, nil, ["foo"])
        Nitra::CommandLine.new(config, ["-e", "foo"])
        config.verify
      end
    end

    describe "--rake-after-runner" do
      it "adds rake tasks to run after runner finishes" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:add_rake_task, nil, [:after_runner, ['list:of','rake:tasks']])
        Nitra::CommandLine.new(config, ['--rake-after-runner', 'list:of,rake:tasks'])
        config.verify
      end
    end

    describe "--rake-before-runner" do
      it "adds rake tasks to run before runner starts" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:add_rake_task, nil, [:before_runner, ['list:of','rake:tasks']])
        Nitra::CommandLine.new(config, ['--rake-before-runner', 'list:of,rake:tasks'])
        config.verify
      end
    end

    describe "--rake-before-worker" do
      it "adds rake tasks to run before worker starts" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:add_rake_task, nil, [:before_worker, ['list:of','rake:tasks']])
        Nitra::CommandLine.new(config, ['--rake-before-worker', 'list:of,rake:tasks'])
        config.verify
      end
    end

    describe "-r" do
      it "adds the db:reset rake task to run before worker starts" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode, false)
        config.expect(:add_rake_task, nil, [:before_worker, 'db:reset'])
        Nitra::CommandLine.new(config, ['-r'])
        config.verify
      end
    end

    describe "--reset" do
      it "adds the db:reset rake task to run before worker starts" do
        config.expect(:frameworks, {})
        config.expect(:add_rake_task, nil, [:before_worker, 'db:reset'])
        config.expect(:slave_mode, false)
        Nitra::CommandLine.new(config, ['--reset'])
        config.verify
      end
    end

    describe "--rspec" do
      it "adds rspec to framework" do
        config.expect(:add_framework, nil, ['rspec', ["spec/**/*_spec.rb"]])
        config.expect(:frameworks, {'rspec' => ["spec/**/*_spec.rb"]})
        Nitra::CommandLine.new(config, ['--rspec'])
        config.verify
      end
    end

    describe "--rspec-format" do
      it "adds the rspec formatter flag" do
        config.expect(:frameworks, {})
        config.expect(:rspec_formatter=, nil, ['thing'])
        config.expect(:slave_mode, false)
        Nitra::CommandLine.new(config, ['--rspec-format', 'thing'])
        config.verify
      end
    end

    describe "--rspec-out" do
      it "adds the rspec formatter flag" do
        config.expect(:frameworks, {})
        config.expect(:rspec_out=, nil, ['file'])
        config.expect(:slave_mode, false)
        Nitra::CommandLine.new(config, ['--rspec-out', 'file'])
        config.verify
      end
    end

    describe "--slave-mode" do
      it "turns on slave mode" do
        config.expect(:frameworks, {})
        config.expect(:slave_mode=, nil, [true])
        config.expect(:slave_mode, true)
        Nitra::CommandLine.new(config, ['--slave-mode'])
        config.verify
      end
    end

    describe "--slave" do
      it "adds a command that will be run later as a slave" do
        config.expect(:frameworks, {})
        config.expect(:add_slave, nil, ['the command to run'])
        config.expect(:slave_mode, false)
        Nitra::CommandLine.new(config, ['--slave', 'the command to run'])
        config.verify
      end
    end
  end

  describe "file lists" do
    it "parses out options and leavs only files in list" do
      argv = ['--slave','the slave command','this_test_file_spec.rb']
      config.expect(:add_slave, nil, ['the slave command'])
      Nitra::CommandLine.new(config, argv)
      config.verify
      argv.must_equal ['this_test_file_spec.rb']
    end
  end
end
