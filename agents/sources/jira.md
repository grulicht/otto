---
name: jira
description: Jira project management via REST API or MCP for issues, sprints, and boards
type: api
required_env:
  - OTTO_JIRA_URL
  - OTTO_JIRA_EMAIL
  - OTTO_JIRA_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -u '${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}' '${OTTO_JIRA_URL}/rest/api/3/myself' | jq -r '.displayName'"
---

# Jira

## Connection

OTTO connects to Jira through the REST API or Atlassian MCP when available.
Authentication uses email + API token (Jira Cloud) or personal access token
(Jira Data Center).

**Jira Cloud**:
```bash
curl -sf -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${OTTO_JIRA_URL}/rest/api/3/<endpoint>"
```

**Jira Data Center**:
```bash
curl -sf -H "Authorization: Bearer ${OTTO_JIRA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${OTTO_JIRA_URL}/rest/api/2/<endpoint>"
```

**MCP**: When the Atlassian MCP server is connected, use its tools for
richer Jira integration.

## Available Data

- **Issues**: Create, read, update, transition, and search issues via JQL
- **Projects**: List projects, project details, and versions
- **Boards**: List boards, sprints, and backlogs (Agile API)
- **Sprints**: View active sprints, sprint reports, and velocity
- **Comments**: Add and read issue comments
- **Worklogs**: Track and report time spent
- **Transitions**: Move issues through workflow states
- **Components**: Manage project components
- **Filters**: Manage saved JQL filters
- **Webhooks**: Configure automation webhooks

## Common Queries

### Search issues with JQL
```bash
curl -sf -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  -G "${OTTO_JIRA_URL}/rest/api/3/search" \
  --data-urlencode "jql=project = OPS AND status = Open ORDER BY priority DESC" \
  --data-urlencode "maxResults=20" | jq '.issues[] | {key, summary: .fields.summary, status: .fields.status.name}'
```

### Create an issue
```bash
curl -sf -X POST -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"project":{"key":"OPS"},"summary":"Issue title","issuetype":{"name":"Task"},"priority":{"name":"High"},"description":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Description here"}]}]}}}' \
  "${OTTO_JIRA_URL}/rest/api/3/issue" | jq '.key'
```

### Transition an issue
```bash
# First get available transitions
curl -sf -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  "${OTTO_JIRA_URL}/rest/api/3/issue/<key>/transitions" | jq '.transitions'

# Then perform the transition
curl -sf -X POST -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"transition":{"id":"<transition-id>"}}' \
  "${OTTO_JIRA_URL}/rest/api/3/issue/<key>/transitions"
```

### List active sprint issues
```bash
curl -sf -u "${OTTO_JIRA_EMAIL}:${OTTO_JIRA_TOKEN}" \
  -G "${OTTO_JIRA_URL}/rest/api/3/search" \
  --data-urlencode "jql=sprint in openSprints() AND project = OPS" | \
  jq '.issues[] | {key, summary: .fields.summary, assignee: .fields.assignee.displayName}'
```
