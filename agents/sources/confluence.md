---
name: confluence
description: Atlassian Confluence wiki via REST API for documentation and runbooks
type: api
required_env:
  - OTTO_CONFLUENCE_URL
  - OTTO_CONFLUENCE_USER
  - OTTO_CONFLUENCE_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sfu '${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}' '${OTTO_CONFLUENCE_URL}/rest/api/space?limit=1' | jq -r '.results[0].key'"
---

# Confluence

## Connection

OTTO connects to Confluence through the REST API using basic authentication
(email + API token for Confluence Cloud) or personal access tokens (Confluence Server/DC).

```bash
curl -sfu "${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}" \
  "${OTTO_CONFLUENCE_URL}/rest/api/<endpoint>"
```

## Available Data

- **Spaces**: List and manage spaces
- **Pages**: Create, read, update, and delete pages
- **Search**: CQL-based content search
- **Labels**: Tag and filter content
- **Attachments**: Upload and manage file attachments
- **Comments**: Page and inline comments

## Common Queries

### Search for runbooks
```bash
curl -sfu "${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}" \
  "${OTTO_CONFLUENCE_URL}/rest/api/content/search?cql=label=runbook&limit=20" | \
  jq '.results[] | {id, title, status: .status}'
```

### Get page content
```bash
curl -sfu "${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}" \
  "${OTTO_CONFLUENCE_URL}/rest/api/content/<page-id>?expand=body.storage" | \
  jq '{title, body: .body.storage.value}'
```

### Create a post-mortem page
```bash
curl -sf -X POST "${OTTO_CONFLUENCE_URL}/rest/api/content" \
  -u "${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "page",
    "title": "Post-Mortem: Incident 2024-01-15",
    "space": {"key": "OPS"},
    "body": {"storage": {"value": "<h1>Summary</h1><p>Details here</p>", "representation": "storage"}}
  }' | jq '{id, title}'
```

### List spaces
```bash
curl -sfu "${OTTO_CONFLUENCE_USER}:${OTTO_CONFLUENCE_TOKEN}" \
  "${OTTO_CONFLUENCE_URL}/rest/api/space?limit=50" | \
  jq '.results[] | {key, name, type}'
```
