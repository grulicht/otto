---
name: linear
description: Linear issue tracking via GraphQL API for project and issue management
type: api
required_env:
  - OTTO_LINEAR_API_KEY
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: ${OTTO_LINEAR_API_KEY}' -H 'Content-Type: application/json' -d '{\"query\":\"{viewer{name}}\"}' 'https://api.linear.app/graphql' | jq -r '.data.viewer.name'"
---

# Linear

## Connection

OTTO connects to Linear through the GraphQL API using a personal API key
or OAuth2 token.

```bash
curl -sf "https://api.linear.app/graphql" \
  -H "Authorization: ${OTTO_LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"<graphql-query>"}'
```

## Available Data

- **Issues**: Create, read, update issues and sub-issues
- **Projects**: Project tracking and milestones
- **Cycles**: Sprint/cycle management
- **Teams**: Team workload and assignments
- **Labels**: Label management
- **Comments**: Issue comments and activity

## Common Queries

### List open issues assigned to team
```bash
curl -sf "https://api.linear.app/graphql" \
  -H "Authorization: ${OTTO_LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ issues(filter: { state: { type: { nin: [\"completed\",\"canceled\"] } } }, first: 50) { nodes { identifier title priority state { name } assignee { name } } } }"}' | \
  jq '.data.issues.nodes[] | {identifier, title, priority, state: .state.name, assignee: .assignee.name}'
```

### Create an issue
```bash
curl -sf "https://api.linear.app/graphql" \
  -H "Authorization: ${OTTO_LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { issueCreate(input: { teamId: \"<team-id>\", title: \"Investigate high latency\", priority: 2 }) { success issue { identifier url } } }"}' | \
  jq '.data.issueCreate.issue'
```

### Get project progress
```bash
curl -sf "https://api.linear.app/graphql" \
  -H "Authorization: ${OTTO_LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ projects(first: 10) { nodes { name progress state } } }"}' | \
  jq '.data.projects.nodes[]'
```
