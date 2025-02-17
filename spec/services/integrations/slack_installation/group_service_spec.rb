# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInstallation::GroupService, feature_category: :integrations do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let(:params) { {} }

  subject(:service) { described_class.new(group, current_user: user, params: params) }

  before_all do
    group.add_owner(user)
  end

  it_behaves_like Integrations::SlackInstallation::BaseService do
    let(:installation_alias) { group.full_path }
    let(:integration) { Integrations::GitlabSlackApplication.for_group(group).first }
    let(:redirect_url) { Gitlab::Routing.url_helpers.slack_auth_group_settings_slack_url(group) }

    def create_gitlab_slack_application_integration!
      Integrations::GitlabSlackApplication.create!(group: group)
    end
  end
end
