---
name: statuspage
description: Atlassian StatusPage for public status communication and incident updates
type: api
required_env:
  - OTTO_STATUSPAGE_API_KEY
  - OTTO_STATUSPAGE_PAGE_ID
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}' 'https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}' | jq -r '.name'"
---

# StatusPage

## Connection

OTTO connects to Atlassian StatusPage through the REST API using an API key.

```bash
curl -sf "https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}/<endpoint>" \
  -H "Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}"
```

## Available Data

- **Components**: List and update component status
- **Incidents**: Create, update, and resolve incidents
- **Scheduled Maintenance**: Create and manage maintenance windows
- **Subscribers**: Manage notification subscribers
- **Metrics**: Submit custom metrics for display

## Common Queries

### List components and status
```bash
curl -sf -H "Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}" \
  "https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}/components" | \
  jq '.[] | {id, name, status}'
```

### Create an incident
```bash
curl -sf -X POST "https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}/incidents" \
  -H "Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "incident": {
      "name": "Elevated error rates on API",
      "status": "investigating",
      "impact_override": "minor",
      "body": "We are investigating elevated error rates.",
      "component_ids": ["<component-id>"],
      "components": {"<component-id>": "degraded_performance"}
    }
  }' | jq '{id, name, status}'
```

### Resolve an incident
```bash
curl -sf -X PATCH "https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}/incidents/<incident-id>" \
  -H "Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"incident":{"status":"resolved","body":"Issue has been resolved."}}' | jq '{id, status}'
```
