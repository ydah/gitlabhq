# frozen_string_literal: true

module Backup
  module Tasks
    class CiSecureFiles < Task
      def self.id = 'ci_secure_files'

      def human_name = _('ci secure files')

      def destination_path = 'ci_secure_files.tar.gz'

      def target
        excludes = ['tmp']

        ::Backup::Targets::Files.new(progress, storage_path, options: options, excludes: excludes)
      end

      private

      def storage_path
        Settings.ci_secure_files.storage_path
      end
    end
  end
end
