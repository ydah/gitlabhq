---
stage: Govern
group: Authentication
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Application statistics API

DETAILS:
**Tier:** Free, Premium, Ultimate
**Offering:** Self-managed

## Get current application statistics

List the current statistics of the GitLab instance. You have to be an
administrator to perform this action.

NOTE:
These statistics show exact counts for values less than 10,000. For values of 10,000 and higher, these statistics show approximate data
when [TablesampleCountStrategy](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/database/count/tablesample_count_strategy.rb?ref_type=heads#L16) and [ReltuplesCountStrategy](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/database/count/reltuples_count_strategy.rb?ref_type=heads) strategies are used for calculations.

```plaintext
GET /application/statistics
```

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/application/statistics"
```

Example response:

```json
{
   "forks": "10",
   "issues": "76",
   "merge_requests": "27",
   "notes": "954",
   "snippets": "50",
   "ssh_keys": "10",
   "milestones": "40",
   "users": "50",
   "groups": "10",
   "projects": "20",
   "active_users": "50"
}
```
