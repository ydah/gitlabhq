---
stage: Govern
group: Authorization
info: Any user with at least the Maintainer role can merge updates to this content. For details, see https://docs.gitlab.com/ee/development/development_processes.html#development-guidelines-review.
---

# Custom Roles

Ultimate customers can create custom roles and define those roles by assigning specific abilities.

For example, a user could create an "Engineer" role with `read code` and `admin merge requests` abilities, but without abilities like `admin issues`.

In this context, the terms "permission" and "ability" are often used interchangeably.

- "Ability" is an action a user can do. These map to [Declarative Policy abilities](https://gitlab.com/gitlab-org/ruby/gems/declarative-policy/-/blob/main/doc/defining-policies.md#rules) and live in Policy classes in `ee/app/policies/*`.
- "Permission" is how we refer to an ability [in user-facing documentation](../../user/permissions.md). The documentation of permissions is manually generated so there is not necessarily a 1:1 mapping of the permissions listed in documentation and the abilities defined in Policy classes.

## Custom roles vs default roles

In GitLab 15.9 and earlier, GitLab only had [default roles](predefined_roles.md) as a permission system. In this system, there are a few predefined roles that are statically assigned to certain abilities. These default roles are not customizable by customers.

With custom roles, the customers can decide which abilities they want to assign to certain user groups. For example:

- In the default role system, reading of vulnerabilities is limited to a Developer role.
- In the custom role system, a customer can assign this ability to a new custom role based on any default role.

Like default roles, custom roles are [inherited](../../user/project/members/index.md#inherited-membership) within a group hierarchy. If a user has custom role for a group, that user will also have a custom role for any projects or subgroups within the group.

## Technical overview

- Individual custom roles are stored in the `member_roles` table (`MemberRole` model).
- A `member_roles` record is associated with top-level groups (not subgroups) via the `namespace_id` foreign key.
- A Group or project membership (`members` record) is associated with a custom role via the `member_role_id` foreign key.
- A Group or project membership can be associated with any custom role that is defined on the root-level group of the group or project.
- The `member_roles` table includes individual permissions and a `base_access_level` value.
- The `base_access_level` must be a [valid access level](../../api/access_requests.md#valid-access-levels).
  The `base_access_level` determines which abilities are included in the custom role. For example, if the `base_access_level` is `10`, the custom role will include any abilities that a default Guest role would receive, plus any additional abilities that are enabled by the `member_roles` record by setting an attribute, such as `read_code`, to true.
- A custom role can enable additional abilities for a `base_access_level` but it cannot disable a permission. As a result, custom roles are "additive only". The rationale for this choice is [in this comment](https://gitlab.com/gitlab-org/gitlab/-/issues/352891#note_1059561579).
- Custom role abilities are supported at project level and group level.

## How to implement a new ability for custom roles

Usually 2-3 merge requests should be created for a new ability. The rough guidance is following:

1. Pick a feature you want to add abilities to custom roles.
1. Refactor & consolidate abilities for the feature (1-2 merge requests depending on the feature complexity)
1. Implement a new ability (1 merge request)

### Refactoring abilities

#### Finding existing abilities checks

Abilities are often [checked in multiple locations](../permissions/authorizations.md#where-should-permissions-be-checked) for a single endpoint or web request. Therefore, it can be difficult to find the list of authorization checks that are run for a given endpoint.

To assist with this, you can locally set `GITLAB_DEBUG_POLICIES=true`.

This outputs information about which abilities are checked in the requests
made in any specs that you run. The output also includes the line of code where the
authorization check was made. Caller information is especially helpful in cases
where there is metaprogramming used because those cases are difficult to find by
grepping for ability name strings.

For example:

```shell
# example spec run

GITLAB_DEBUG_POLICIES=true bundle exec rspec spec/controllers/groups_controller_spec.rb:162

# permissions debug output when spec is run; if multiple policy checks are run they will all be in the debug output.

POLICY CHECK DEBUG -> policy: GlobalPolicy, ability: create_group, called_from: ["/gitlab/app/controllers/application_controller.rb:245:in `can?'", "/gitlab/app/controllers/groups_controller.rb:255:in `authorize_create_group!'"]
```

Use this setting to learn more about authorization checks while
refactoring. You should not keep this setting enabled for any specs on the default branch.

#### Understanding logic for individual abilities

References to an ability may appear in a `DeclarativePolicy` class many times
and depend on conditions and rules which reference other abilities. As a result,
it can be challenging to know exactly which conditions apply to a particular
ability.

`DeclarativePolicy` provides a `ability_map` for each policy class, which
pulls all rules for an ability into an array.

For example:

```ruby
> GroupPolicy.ability_map.map.select { |k,v| k == :read_group_member }
=> {:read_group_member=>[[:enable, #<Rule can?(:read_group)>], [:prevent, #<Rule ~can_read_group_member>]]}

> GroupPolicy.ability_map.map.select { |k,v| k == :read_group }
=> {:read_group=>
  [[:enable, #<Rule public_group>],
   [:enable, #<Rule logged_in_viewable>],
   [:enable, #<Rule guest>],
   [:enable, #<Rule admin>],
   [:enable, #<Rule has_projects>],
   [:enable, #<Rule read_package_registry_deploy_token>],
   [:enable, #<Rule write_package_registry_deploy_token>],
   [:prevent, #<Rule all?(~public_group, ~admin, user_banned_from_group)>],
   [:enable, #<Rule auditor>],
   [:prevent, #<Rule needs_new_sso_session>],
   [:prevent, #<Rule all?(ip_enforcement_prevents_access, ~owner, ~auditor)>]]}
```

`DeclarativePolicy` also provides a `debug` method that can be used to
understand the logic tree for a specific object and actor. The output is similar
to the list of rules from `ability_map`. But, `DeclarativePolicy` stops
evaluating rules after you `prevent` an ability, so it is possible that
not all conditions are called.

Example:

```ruby
policy = GroupPolicy.new(User.last,  Group.last)
policy.debug(:read_group)

- [0] enable when public_group ((@custom_guest_user1 : Group/139))
- [0] enable when logged_in_viewable ((@custom_guest_user1 : Group/139))
- [0] enable when admin ((@custom_guest_user1 : Group/139))
- [0] enable when auditor ((@custom_guest_user1 : Group/139))
- [14] prevent when all?(~public_group, ~admin, user_banned_from_group) ((@custom_guest_user1 : Group/139))
- [14] prevent when needs_new_sso_session ((@custom_guest_user1 : Group/139))
- [16] enable when guest ((@custom_guest_user1 : Group/139))
- [16] enable when has_projects ((@custom_guest_user1 : Group/139))
- [16] enable when read_package_registry_deploy_token ((@custom_guest_user1 : Group/139))
- [16] enable when write_package_registry_deploy_token ((@custom_guest_user1 : Group/139))
  [21] prevent when all?(ip_enforcement_prevents_access, ~owner, ~auditor) ((@custom_guest_user1 : Group/139))

=> #<DeclarativePolicy::Runner::State:0x000000015c665050
 @called_conditions=
  #<Set: {
   "/dp/condition/GroupPolicy/public_group/Group:139",
   "/dp/condition/GroupPolicy/logged_in_viewable/User:83,Group:139",
   "/dp/condition/BasePolicy/admin/User:83",
   "/dp/condition/BasePolicy/auditor/User:83",
   "/dp/condition/GroupPolicy/user_banned_from_group/User:83,Group:139",
   "/dp/condition/GroupPolicy/needs_new_sso_session/User:83,Group:139",
   "/dp/condition/GroupPolicy/guest/User:83,Group:139",
   "/dp/condition/GroupPolicy/has_projects/User:83,Group:139",
   "/dp/condition/GroupPolicy/read_package_registry_deploy_token/User:83,Group:139",
   "/dp/condition/GroupPolicy/write_package_registry_deploy_token/User:83,Group:139"}>,
 @enabled=false,
 @prevented=true>
```

#### Abilities consolidation

Every feature added to custom roles should have minimal abilities. For most features, having `read_*` and `admin_*` should be enough. You should consolidate all:

- View-related abilities under `read_*`. For example, viewing a list or detail.
- Object updates under `admin_*`. For example, updating an object, adding assignees or closing it that object. Usually, a role that enables `admin_` has to have also `read_` abilities enabled. This is defined in `requirement` option in the `ALL_CUSTOMIZABLE_PERMISSIONS` hash on `MemberRole` model.

There might be features that require additional abilities but try to minimize those. You can always ask members of the Authentication and Authorization group for their opinion or help.

This is also where your work should begin. Take all the abilities for the feature you work on, and consolidate those abilities into `read_`, `admin_`, or additional abilities if necessary.

Many abilities in the `GroupPolicy` and `ProjectPolicy` classes have many
redundant policies. There is an [epic for consolidating these Policy classes](https://gitlab.com/groups/gitlab-org/-/epics/6689).
If you encounter similar permissions in these classes, consider refactoring so
that they have the same name.

For example, you see in `GroupPolicy` that there is an ability called
`read_group_security_dashboard` and in `ProjectPolicy` has an ability called
`read_project_security_dashboard`. You'd like to make both customizable. Rather
than adding a row to the `member_roles` table for each ability, consider
renaming them to `read_security_dashboard` and adding `read_security_dashboard`
to the `member_roles` table. Enabling `read_security_dashboard` on
the parent group will allow the custom role to access the group security dashboard and the project security dashboard
for each project in that group. Enabling the same permission on a specific project will allow access to that projects'
security dashboard.

### Implement a new ability

#### Step 1. Generate a configuration file

- Run `./ee/bin/custom-ability <ABILITY_NAME>` to generate a configuration file for the new ability.
- This will generate a YAML file in `ee/config/custom_abilities` which follows the following schema:

| Field | Required | Description |
| ----- | -------- |--------------|
| `name` | yes     | Unique, lowercase and underscored name describing the custom ability. Must match the filename. |
| `description` | yes | Human-readable description of the custom ability. |
| `feature_category` | yes | Name of the feature category. For example, `vulnerability_management`. |
| `introduced_by_issue` | yes | Issue URL that proposed the addition of this custom ability. |
| `introduced_by_mr` | yes | MR URL that added this custom ability. |
| `milestone` | yes | Milestone in which this custom ability was added. |
| `group_ability` | yes | Boolean value to indicate whether this ability is checked on group level. |
| `project_ability` | yes | Boolean value to whether this ability is checked on project level. |
| `requirements` | no | The list of custom permissions this ability is dependent on. For instance `admin_vulnerability` is dependent on `read_vulnerability`. If none, then enter `[]`  |
| `available_from_access_level` | no | The access level from which this ability is available, if applicable. See the section on [understanding logic for individual abilities](#understanding-logic-for-individual-abilities) for help on determining the base access level for an ability. |

#### Step 2: Create a migration file

- Run `bundle exec rails generate gitlab:custom_roles:code --ability <ABILITY_NAME>` which will generate a migration file to add the ability as a boolean column to the `member_roles` table.

#### Step 3: Update policies

- If the ability is checked on a group level, add rule(s) to GroupPolicy to enable the ability.
- For example: if the ability we would like to add is `read_dependency`, then an update to `ee/app/policies/ee/group_policy.rb` would look like as follows:

```ruby
desc "Custom role on group that enables read dependency"
condition(:role_enables_read_dependency) do
  ::Auth::MemberRoleAbilityLoader.new(
    user: @user,
    resource: @subject,
    ability: :read_dependency
  ).has_ability?
end

rule { custom_roles_allowed & role_enables_read_dependency }.policy do
  enable :read_dependency
end
```

- Similarly, If the ability is checked on a project level, add rule(s) to ProjectPolicy to enable the ability.
- For example: if the ability we would like to add is `read_dependency`, then an update to `ee/app/policies/ee/project_policy.rb` would look like as follows:

```ruby
desc "Custom role on project that enables read dependency"
condition(:role_enables_read_dependency) do
  ::Auth::MemberRoleAbilityLoader.new(
    user: @user,
    resource: @subject,
    ability: :read_dependency
  ).has_ability?
end

rule { custom_roles_allowed & role_enables_read_dependency }.policy do
  enable :read_dependency
end
```

- Not all abilities need to be enabled on both levels, for instance `admin_terraform_state` allows users to manage a project's terraform state. It only needs to be enabled on the project level and not the group level, and thus only needs to be configured in `ee/app/policies/ee/project_policy.rb`.

#### Step 4: Verify

- Ensure SaaS mode is enabled with `GITLAB_SIMULATE_SAAS=1`.
- Navigate to any Group that you are an owner of, then go to `Settings -> Roles and Permissions`.
- Click on `Add new role` and create a custom role with the permission you have just created.
- Navigate to the Group's `Manage -> Members` page and assign a member to this newly created custom role.
- Next, log-in as that member and ensure that you are able to access the page that the custom ability is intended for.

#### Step 5: Add specs

- Add the ability as a trait in the `MemberRoles` factory, `ee/spec/factories/member_roles.rb`.
- Add tests to `ee/spec/requests/custom_roles/<ABILITY_NAME>/request_spec.rb` to ensure that once the user has been assigned the custom ability, they can successfully access the controllers, REST API endpoints and GraphQL API endpoints.
- Below is an example of the typical setup that is required to test a Rails Controller endpoint.

```ruby
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :in_group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: project.group, custom_permission: true) }
  let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe MyController do
    describe '#show' do
      it 'allows access' do
        get my_controller_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end
  end
```

- Below is an example of the typical setup that is required to test a GraphQL mutation.

```ruby
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :in_group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: project.group, custom_permission: true) }
  let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe MyMutation do
    include GraphqlHelpers

    describe '#show' do
      let(:mutation) { graphql_mutation(:my_mutation) }

      it_behaves_like 'a working graphql query'
    end
  end
```

- Add tests to `ProjectPolicy` and/or `GroupPolicy`. Below is an example for testing `ProjectPolicy` related changes.

```ruby
  context 'for a member role with read_dependency true' do
    let(:member_role_abilities) { { read_dependency: true } }
    let(:allowed_abilities) { [:read_dependency] }

    it_behaves_like 'custom roles abilities'
  end
```

#### Step 6: Update documentation

- Update the list of custom abilities by running `bundle exec rake gitlab:custom_roles:compile_docs`
- Update the GraphQL documentation by running `bundle exec rake gitlab:graphql:compile_docs`

### Privilege escalation consideration

A base role typically has permissions that allow creation or management of artifacts corresponding to the base role when interacting with that artifact. For example, when a `Developer` creates an access token for a project, it is created with `Developer` access encoded into that credential. It is important to keep in mind that as new custom permissions are created, there might be a risk of elevated privileges when interacting with GitLab artifacts, and appropriate safeguards or base role checks should be added.

### Consuming seats

If a new user with a role `Guest` is added to a member role that includes enablement of an ability that is **not** in the `CUSTOMIZABLE_PERMISSIONS_EXEMPT_FROM_CONSUMING_SEAT` array, a seat is consumed. We simply want to make sure we are charging Ultimate customers for guest users, who have "elevated" abilities. This only applies to billable users on SaaS (billable users that are counted towards namespace subscription). More details about this topic can be found in [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390269).
