# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting organizations information', feature_category: :cell do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  let(:query) { graphql_query_for(:organizations, organizations_fields) }
  let(:organizations) { graphql_data_at(:organizations, :nodes) }
  let(:organizations_fields) do
    <<~FIELDS
    nodes {
      id
      path
    }
    FIELDS
  end

  before_all { create_list(:organization, 3) }

  subject(:request_organization) { post_graphql(query, current_user: current_user) }

  context 'without authenticated user' do
    let(:current_user) { nil }

    it_behaves_like 'a working graphql query' do
      before do
        request_organization
      end
    end
  end

  context 'with authenticated user' do
    let(:current_user) { user }

    it_behaves_like 'a working graphql query' do
      before do
        request_organization
      end
    end

    it_behaves_like 'sorted paginated query' do
      include_context 'no sort argument'

      let(:first_param) { 2 }
      let(:data_path) { [:organizations] }
      let(:all_records) { Organizations::Organization.order(id: :desc).map { |o| global_id_of(o).to_s } }
    end

    def pagination_query(params)
      graphql_query_for(:organizations, params, "#{page_info} nodes { id }")
    end
  end
end
