---
name: gitlab
description: GitLab DevOps platform via glab CLI or REST/GraphQL API
type: cli
required_env:
  - OTTO_GITLAB_URL
  - OTTO_GITLAB_TOKEN
required_tools:
  - glab
  - curl
  - jq
check_command: "curl -sf -H 'PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}' '${OTTO_GITLAB_URL}/api/v4/version' | jq -r '.version'"
---

# GitLab

## Connection

OTTO connects to GitLab through the `glab` CLI (preferred) or the REST/GraphQL API.

**glab CLI** (preferred):
```bash
export GITLAB_HOST="${OTTO_GITLAB_URL}"
export GITLAB_TOKEN="${OTTO_GITLAB_TOKEN}"
glab <command>
```

**REST API**:
```bash
curl -sf -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
  "${OTTO_GITLAB_URL}/api/v4/<endpoint>"
```

**GraphQL API**:
```bash
curl -sf -X POST -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ currentUser { name } }"}' \
  "${OTTO_GITLAB_URL}/api/graphql"
```

## Available Data

- **Projects**: List, search, and manage repositories
- **Merge Requests**: Create, list, review, approve, and merge MRs
- **Pipelines**: List pipeline runs, view jobs, retry/cancel pipelines
- **Issues**: Create, list, update, and close issues
- **Environments**: List environments and deployments
- **Container Registry**: List images and tags
- **Releases**: List and create releases
- **Wiki**: Access project wikis
- **Snippets**: Manage code snippets
- **CI/CD Variables**: Manage project and group variables

## Common Queries

### List merge requests
```bash
glab mr list --state=opened
```

### View pipeline status
```bash
glab ci list
glab ci view <pipeline-id>
```

### List failing pipelines
```bash
curl -sf -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
  "${OTTO_GITLAB_URL}/api/v4/projects/<id>/pipelines?status=failed&per_page=10" | jq '.'
```

### Get deployment status
```bash
curl -sf -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
  "${OTTO_GITLAB_URL}/api/v4/projects/<id>/environments" | jq '.[].name'
```

### Trigger a pipeline
```bash
curl -sf -X POST -H "PRIVATE-TOKEN: ${OTTO_GITLAB_TOKEN}" \
  "${OTTO_GITLAB_URL}/api/v4/projects/<id>/pipeline" \
  -d '{"ref":"main"}'
```

### Search across projects
```bash
glab search --type=project "search-term"
```
