# frozen_string_literal: true

class RemovePhabricatorFromApplicationSettings < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  class ApplicationSetting < MigrationRecord
  end

  def up
    # rubocop: disable Style/GuardClause
    unless import_sources.empty?
      ApplicationSetting.update_all(import_sources: import_sources.reject { |x| x == "phabricator" })
    end
    # rubocop: enable Style/GuardClause
  end

  def down
    ## a reversion is not needed as Phabricator is no longer a supported import source
    #  and attempting to save it as one will result in a ActiveRecord error.
  end

  def import_sources
    ## the last ApplicationSetting record is used to determine application settings
    import_sources = ApplicationSetting.last&.import_sources
    import_sources.nil? ? [] : YAML.safe_load(import_sources)
  end
end
