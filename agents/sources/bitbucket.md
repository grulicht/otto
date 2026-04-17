---
name: bitbucket
description: Bitbucket Cloud/Server via REST API for repositories, PRs, and pipelines
type: api
required_env:
  - OTTO_BITBUCKET_USER
  - OTTO_BITBUCKET_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -u '${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}' 'https://api.bitbucket.org/2.0/user' | jq -r '.display_name'"
---

# Bitbucket

## Connection

OTTO connects to Bitbucket via the REST API using HTTP basic authentication
with an app password or personal access token.

**Bitbucket Cloud**:
```bash
curl -sf -u "${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}" \
  "https://api.bitbucket.org/2.0/<endpoint>"
```

**Bitbucket Server/Data Center**: Set `OTTO_BITBUCKET_URL` to the server base URL
and use personal access tokens:
```bash
curl -sf -H "Authorization: Bearer ${OTTO_BITBUCKET_TOKEN}" \
  "${OTTO_BITBUCKET_URL}/rest/api/1.0/<endpoint>"
```

## Available Data

- **Repositories**: List, search, and manage repos within a workspace
- **Pull Requests**: Create, list, review, approve, merge, and decline PRs
- **Pipelines**: List pipeline runs, view step logs, trigger pipelines
- **Branches**: List, create, and manage branches and branch restrictions
- **Commits**: List commits, view diffs, and comment on commits
- **Issues**: Create, list, and manage issues (if issue tracker is enabled)
- **Deployments**: List environments and deployment history
- **Webhooks**: Manage repository webhooks
- **Downloads**: Manage repository downloads/artifacts

## Common Queries

### List open pull requests
```bash
curl -sf -u "${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}" \
  "https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>/pullrequests?state=OPEN" | \
  jq '.values[] | {id, title, author: .author.display_name, state}'
```

### List recent pipelines
```bash
curl -sf -u "${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}" \
  "https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>/pipelines/?sort=-created_on&pagelen=10" | \
  jq '.values[] | {uuid, state: .state.name, target: .target.ref_name}'
```

### List repositories in workspace
```bash
curl -sf -u "${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}" \
  "https://api.bitbucket.org/2.0/repositories/<workspace>?pagelen=25" | \
  jq '.values[] | {slug, name, language}'
```

### Get branch restrictions
```bash
curl -sf -u "${OTTO_BITBUCKET_USER}:${OTTO_BITBUCKET_TOKEN}" \
  "https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>/branch-restrictions" | \
  jq '.values'
```
