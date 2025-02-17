# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User manages the group-level GitLab for Slack app integration', :js, feature_category: :integrations do
  include Spec::Support::Helpers::ModalHelpers

  include_context 'group integration activation'

  let_it_be(:integration) do
    create(:gitlab_slack_application_integration, :group, group: group,
      slack_integration: build(:slack_integration)
    )
  end

  before do
    stub_application_setting(slack_app_enabled: true)
  end

  def visit_slack_application_form
    visit_group_integration('GitLab for Slack app')
    wait_for_requests
  end

  context 'when the flag is disabled' do
    before do
      stub_feature_flags(gitlab_for_slack_app_instance_and_group_level: false)
    end

    it 'hides the integration' do
      visit_group_integrations

      expect(page).not_to have_content('GitLab for Slack app')
    end
  end

  it 'shows the workspace name but not the alias and does not allow the user to edit it' do
    visit_slack_application_form

    within_testid 'integration-settings-form' do
      expect(page).to have_content('Workspace name')
      expect(page).to have_content(integration.slack_integration.team_name)
      expect(page).not_to have_content('Project alias')
      expect(page).not_to have_content(integration.slack_integration.alias)
      expect(page).not_to have_content('Edit')
    end
  end

  it 'allows the user to unlink the GitLab for Slack app' do
    visit_slack_application_form

    within_testid 'integration-settings-form' do
      page.find('a.btn-danger').click
    end

    within_modal do
      expect(page).to have_content('Are you sure you want to unlink this Slack Workspace from this integration?')
      click_button('Remove')
    end

    wait_for_requests

    expect(page).to have_content('Install GitLab for Slack app')
  end

  it 'shows the trigger form fields' do
    visit_slack_application_form

    expect(page).to have_selector('[data-testid="trigger-fields-group"]')
  end

  context 'when the integration is disabled' do
    before do
      Integrations::GitlabSlackApplication.for_group(group).first.update!(active: false)
    end

    it 'does not show the trigger form fields' do
      visit_slack_application_form

      expect(page).not_to have_selector('[data-testid="trigger-fields-group"]')
    end
  end
end
