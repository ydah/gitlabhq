# frozen_string_literal: true

# goal of this context: provide an easy process for setting and using the current organization that is set
# in the middleware for non-feature spec level specs.
RSpec.shared_context 'with current_organization setting', shared_context: :metadata do # rubocop:disable RSpec/SharedGroupsMetadata -- We are actually using this for easy metadata setting
  let_it_be(:current_organization, reload: true) { create(:organization, name: 'Current Organization') }

  around do |example|
    Current.set(organization: current_organization) { example.run }
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with current_organization setting', with_current_organization: true
end
