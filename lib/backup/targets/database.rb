# frozen_string_literal: true

require 'yaml'

module Backup
  module Targets
    class Database < Target
      extend ::Gitlab::Utils::Override
      include Backup::Helper
      attr_reader :force

      IGNORED_ERRORS = [
        # Ignore warnings
        /WARNING:/,
        # Ignore the DROP errors; recent database dumps will use --if-exists with pg_dump
        /does not exist$/,
        # User may not have permissions to drop extensions or schemas
        /must be owner of/
      ].freeze
      IGNORED_ERRORS_REGEXP = Regexp.union(IGNORED_ERRORS).freeze

      def initialize(progress, options:, force:)
        super(progress, options: options)
        @force = force
      end

      override :dump

      def dump(destination_dir, _)
        FileUtils.mkdir_p(destination_dir)

        each_database(destination_dir) do |backup_connection|
          pg_env = backup_connection.database_configuration.pg_env_variables
          active_record_config = backup_connection.database_configuration.activerecord_variables
          pg_database_name = active_record_config[:database]

          dump_file_name = file_name(destination_dir, backup_connection.connection_name)
          FileUtils.rm_f(dump_file_name)

          progress.print "Dumping PostgreSQL database #{pg_database_name} ... "

          schemas = []

          if Gitlab.config.backup.pg_schema
            schemas << Gitlab.config.backup.pg_schema
            schemas.push(*Gitlab::Database::EXTRA_SCHEMAS.map(&:to_s))
          end

          pg_dump = ::Gitlab::Backup::Cli::Utils::PgDump.new(
            database_name: pg_database_name,
            snapshot_id: backup_connection.snapshot_id,
            schemas: schemas,
            env: pg_env)

          success = Backup::Dump::Postgres.new.dump(dump_file_name, pg_dump)

          backup_connection.release_snapshot! if backup_connection.snapshot_id

          raise DatabaseBackupError.new(active_record_config, dump_file_name) unless success

          report_success(success)

          progress.flush
        end
      ensure
        if multiple_databases?
          ::Gitlab::Database::EachDatabase.each_connection(
            only: base_models_for_backup.keys, include_shared: false
          ) do |_, database_connection_name|
            backup_connection = Backup::DatabaseConnection.new(database_connection_name)
            backup_connection.restore_timeouts!
          rescue ActiveRecord::ConnectionNotEstablished
            raise Backup::DatabaseBackupError.new(
              backup_connection.database_configuration.activerecord_variables,
              file_name(destination_dir, database_connection_name)
            )
          end
        end
      end

      override :restore

      def restore(destination_dir, _)
        base_models_for_backup.each do |database_name, _|
          backup_connection = Backup::DatabaseConnection.new(database_name)

          config = backup_connection.database_configuration.activerecord_variables

          db_file_name = file_name(destination_dir, database_name)
          database = config[:database]

          unless File.exist?(db_file_name)
            raise(Backup::Error, "Source database file does not exist #{db_file_name}") if main_database?(database_name)

            progress.puts "Source backup for the database #{database_name} doesn't exist. Skipping the task"
            return false
          end

          unless force
            progress.puts 'Removing all tables. Press `Ctrl-C` within 5 seconds to abort'.color(:yellow)
            sleep(5)
          end

          # Drop all tables Load the schema to ensure we don't have any newer tables
          # hanging out from a failed upgrade
          drop_tables(database_name)

          pg_env = backup_connection.database_configuration.pg_env_variables
          success = with_transient_pg_env(pg_env) do
            decompress_rd, decompress_wr = IO.pipe
            decompress_pid = spawn(decompress_cmd, out: decompress_wr, in: db_file_name)
            decompress_wr.close

            status, @errors =
              case config[:adapter]
              when "postgresql" then
                progress.print "Restoring PostgreSQL database #{database} ... "
                execute_and_track_errors(pg_restore_cmd(database), decompress_rd)
              end
            decompress_rd.close

            Process.waitpid(decompress_pid)
            $?.success? && status.success?
          end

          if @errors.present?
            progress.print "------ BEGIN ERRORS -----\n".color(:yellow)
            progress.print @errors.join.color(:yellow)
            progress.print "------ END ERRORS -------\n".color(:yellow)
          end

          report_success(success)
          raise Backup::Error, 'Restore failed' unless success
        end
      end

      override :pre_restore_warning

      def pre_restore_warning
        return if force

        <<-MSG.strip_heredoc
        Be sure to stop Puma, Sidekiq, and any other process that
        connects to the database before proceeding. For Omnibus
        installs, see the following link for more information:
        #{help_page_url('raketasks/backup_restore.html', 'restore-for-omnibus-gitlab-installations')}

        Before restoring the database, we will remove all existing
        tables to avoid future upgrade problems. Be aware that if you have
        custom tables in the GitLab database these tables and all data will be
        removed.
        MSG
      end

      override :post_restore_warning

      def post_restore_warning
        return unless @errors.present?

        <<-MSG.strip_heredoc
        There were errors in restoring the schema. This may cause
        issues if this results in missing indexes, constraints, or
        columns. Please record the errors above and contact GitLab
        Support if you have questions:
        https://about.gitlab.com/support/
        MSG
      end

      protected

      def base_models_for_backup
        @base_models_for_backup ||= Gitlab::Database.database_base_models_with_gitlab_shared
      end

      def main_database?(database_name)
        database_name.to_sym == :main
      end

      def file_name(base_dir, database_name)
        prefix = database_name.to_sym != :main ? "#{database_name}_" : ''

        File.join(base_dir, "#{prefix}database.sql.gz")
      end

      def ignore_error?(line)
        IGNORED_ERRORS_REGEXP.match?(line)
      end

      def execute_and_track_errors(cmd, decompress_rd)
        errors = []

        Open3.popen3(ENV, *cmd) do |stdin, stdout, stderr, thread|
          stdin.binmode

          out_reader = Thread.new do
            data = stdout.read
            $stdout.write(data)
          end

          err_reader = Thread.new do
            until (raw_line = stderr.gets).nil?
              warn(raw_line)
              errors << raw_line unless ignore_error?(raw_line)
            end
          end

          begin
            IO.copy_stream(decompress_rd, stdin)
          rescue Errno::EPIPE
          end

          stdin.close
          [thread, out_reader, err_reader].each(&:join)
          [thread.value, errors]
        end
      end

      def report_success(success)
        if success
          progress.puts '[DONE]'.color(:green)
        else
          progress.puts '[FAILED]'.color(:red)
        end
      end

      private

      def drop_tables(database_name)
        puts_time 'Cleaning the database ... '.color(:blue)

        if Rake::Task.task_defined? "gitlab:db:drop_tables:#{database_name}"
          Rake::Task["gitlab:db:drop_tables:#{database_name}"].invoke
        else
          # In single database (single or two connections)
          Rake::Task["gitlab:db:drop_tables"].invoke
        end

        puts_time 'done'.color(:green)
      end

      # @deprecated This will be removed when restore operation is refactored to use extended_env directly
      def with_transient_pg_env(extended_env)
        ENV.merge!(extended_env)
        result = yield
        ENV.reject! { |k, _| extended_env.key?(k) }

        result
      end

      def pg_restore_cmd(database)
        ['psql', database]
      end

      def each_database(destination_dir, &block)
        databases = []

        # each connection will loop through all database connections defined in `database.yml`
        # and reject the ones that are shared, so we don't get duplicates
        #
        # we consider a connection to be shared when it has `database_tasks: false`
        ::Gitlab::Database::EachDatabase.each_connection(
          only: base_models_for_backup.keys, include_shared: false
        ) do |_, database_connection_name|
          backup_connection = Backup::DatabaseConnection.new(database_connection_name)
          databases << backup_connection

          next unless multiple_databases?

          begin
            # Trigger a transaction snapshot export that will be used by pg_dump later on
            backup_connection.export_snapshot!
          rescue ActiveRecord::ConnectionNotEstablished
            raise Backup::DatabaseBackupError.new(
              backup_connection.database_configuration.activerecord_variables,
              file_name(destination_dir, database_connection_name)
            )
          end
        end

        databases.each(&block)
      end

      def multiple_databases?
        Gitlab::Database.database_mode == Gitlab::Database::MODE_MULTIPLE_DATABASES
      end

      def help_page_url(path, anchor = nil)
        ::Gitlab::Routing.url_helpers.help_page_url(path, anchor: anchor)
      end
    end
  end
end
