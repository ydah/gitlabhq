---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Beyond Identity

DETAILS:
**Tier:** Premium, Ultimate
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/431433) in GitLab 16.9.

Configure GitLab to verify GPG keys issued by [Beyond Identity](https://www.beyondidentity.com/)
added to a user profile.

## Set up the Beyond Identity integration for your instance

Prerequisites:

- You must have administrator access to the GitLab instance.
- The email address used in the GitLab profile must be the same as the email assigned to the key in the Beyond Identity Authenticator.
- You must have a Beyond Identity API token. You can request it from their Sales Engineer.

To enable the Beyond Identity integration for your instance:

1. Sign in to GitLab as an administrator.
1. On the left sidebar, at the bottom, select **Admin Area**.
1. Select **Settings > Integrations**.
1. Select **Beyond Identity**.
1. Under **Enable integration**, select the **Active** checkbox.
1. In **API token**, paste the API token you received from Beyond Identity.
1. Select **Save changes**.

The Beyond Identity integration for your instance is now enabled.
When a user adds a GPG key to their profile, the key is verified.
If the key wasn't issued by the Beyond Identity Authenticator or the email used in their GitLab
profile is different from the email assigned to the key in the Beyond Identity Authenticator, it's rejected.
