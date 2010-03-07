# Shell commands module
module Shell
  @@commands = {}
  def self.commands
    @@commands
  end

  @@command_groups = {}
  def self.command_groups
    @@command_groups
  end

  def self.load_command(name, group)
    return if commands[name]

    # Register command in the group
    raise ArgumentError, "Unknown group: #{group}" unless command_groups[group]
    command_groups[group][:commands] << name

    # Load command
    begin
      require "shell/commands/#{name}"
      klass_name = name.to_s.gsub(/(?:^|_)(.)/) { $1.upcase } # camelize
      commands[name] = eval("Commands::#{klass_name}")
    rescue => e
      raise "Can't load hbase shell command: #{name}. Error: #{e}\n#{e.backtrace.join("\n")}"
    end
  end

  def self.load_command_group(group, opts)
    raise ArgumentError, "No :commands for group #{group}" unless opts[:commands]

    command_groups[group] = {
      :commands => [],
      :command_names => opts[:commands],
      :full_name => opts[:full_name] || group,
      :comment => opts[:comment]
    }

    opts[:commands].each do |command|
      load_command(command, group)
    end
  end

  #----------------------------------------------------------------------
  class Shell
    attr_accessor :hbase
    attr_accessor :formatter

    def initialize(hbase, formatter)
      self.hbase = hbase
      self.formatter = formatter
    end

    def hbase_admin
      @hbase_admin ||= hbase.admin(formatter)
    end

    def hbase_table(name)
      hbase.table(name, formatter)
    end

    def export_commands(where)
      ::Shell.commands.keys.each do |cmd|
        where.send :instance_eval, <<-EOF
          def #{cmd}(*args)
            @shell.command('#{cmd}', *args)
          end
        EOF
      end
    end

    def command_instance(command)
      ::Shell.commands[command.to_s].new(self)
    end

    def command(command, *args)
      command_instance(command).command_safe(*args)
    end

    def print_banner
      puts "HBase Shell; enter 'help<RETURN>' for list of supported commands."
      puts 'Type "exit<RETURN>" to leave the HBase Shell'
      command('version')
    end

    def help_command(command)
      puts "COMMAND: #{command}"
      puts command_instance(command).help
      puts
      return nil
    end

    def help_group(group_name)
      group = ::Shell.command_groups[group_name.to_s]
      puts group[:full_name]
      puts '-' * 80
      group[:commands].sort.each { |cmd| help_command(cmd) }
      if group[:comment]
        puts '-' * 80
        puts
        puts group[:comment]
        puts
      end
      return nil
    end

    def help(command = nil)
      puts
      if command
        return help_command(command) if ::Shell.commands[command.to_s]
        return help_group(command) if ::Shell.command_groups[command.to_s]
        puts "ERROR: Invalid command or command group name: #{command}"
        puts
      end

      puts help_header
      puts
      puts '-' * 80
      puts
      puts "Here is the list of groups with their commands:"
      puts
      ::Shell.command_groups.each do |name, group|
        puts "  " + group[:full_name] + ": "
        puts "    group name: " + name
        puts "    commands: " + group[:command_names].sort.join(', ')
        puts
      end
      puts
      unless command
        puts '-' * 80
        puts
        help_footer
        puts
      end
      return nil
    end

    def help_header
      return "There are few groups of commands in Hbase\n\n" +
             "Use help 'group_name' (e.g. help 'general') to get help on all commands in a group\n" +
             "Use help 'command' (e.g. help 'get') to get help on a specific command"
    end

    def help_footer
      puts "GENERAL NOTES:"
      puts <<-HERE
        Quote all names in the hbase shell such as table and column names.  Don't
        forget commas delimit command parameters.  Type <RETURN> after entering a
        command to run it.  Dictionaries of configuration used in the creation and
        alteration of tables are ruby Hashes. They look like this:

          {'key1' => 'value1', 'key2' => 'value2', ...}

        They are opened and closed with curley-braces.  Key/values are delimited by
        the '=>' character combination.  Usually keys are predefined constants such as
        NAME, VERSIONS, COMPRESSION, etc.  Constants do not need to be quoted.  Type
        'Object.constants' to see a (messy) list of all constants in the environment.

        In case you are using binary keys or values and need to enter them into the
        shell then use double-quotes to make use of hexadecimal for example:

          hbase> get 't1', "key\\x03\\x3f\\xcd"
          hbase> get 't1', "key\\003\\023\\011"
          hbase> put 't1', "test\\xef\\xff", 'f1:', "\\x01\\x33\\x40"

        Using the double-quote notation you can directly use the values output by the
        shell for example during a "scan" call.

        This HBase shell is the JRuby IRB with the above HBase-specific commands added.
        For more on the HBase Shell, see http://wiki.apache.org/hadoop/Hbase/Shell
      HERE
    end
  end
end

# Load commands base class
require 'shell/commands'

# Load all commands
Shell.load_command_group(
  'general',
  :full_name => 'GENERAL HBASE SHELL COMMANDS',
  :commands => %w[
    status
    version
  ]
)

Shell.load_command_group(
  'ddl',
  :full_name => 'TABLES MANAGEMENT COMMANDS',
  :commands => %w[
    alter
    create
    describe
    disable
    drop
    enable
    exists
    list
  ]
)

Shell.load_command_group(
  'dml',
  :full_name => 'DATA MANIPULATION COMMANDS',
  :commands => %w[
    count
    delete
    deleteall
    get
    incr
    put
    scan
    truncate
  ]
)

Shell.load_command_group(
  'tools',
  :full_name => 'HBASE SURGERY TOOLS',
  :comment => "WARNING: Above commands are for 'experts'-only as misuse can damage an install",
  :commands => %w[
    close_region
    compact
    disable_region
    enable_region
    flush
    major_compact
    shutdown
    split
    zk
    zk_dump
  ]
)

