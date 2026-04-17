---
name: opsgenie
description: OpsGenie alert management and on-call scheduling via REST API
type: api
required_env:
  - OTTO_OPSGENIE_API_KEY
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}' 'https://api.opsgenie.com/v2/account' | jq -r '.data.name'"
---

# OpsGenie

## Connection

OTTO connects to OpsGenie through the REST API v2 using a GenieKey (API Integration key).
Set `OTTO_OPSGENIE_API_URL` to `https://api.eu.opsgenie.com` for EU instances.

```bash
OPSGENIE_URL="${OTTO_OPSGENIE_API_URL:-https://api.opsgenie.com}"
curl -sf "${OPSGENIE_URL}/v2/<endpoint>" \
  -H "Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}"
```

## Available Data

- **Alerts**: Create, acknowledge, close, and manage alerts
- **Incidents**: Incident management and tracking
- **On-call**: Schedules, rotations, and who-is-on-call
- **Teams**: Team management and routing rules
- **Services**: Service catalog
- **Heartbeats**: Application heartbeat monitoring

## Common Queries

### List open alerts
```bash
curl -sf "${OPSGENIE_URL}/v2/alerts?query=status:open&limit=20" \
  -H "Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}" | \
  jq '.data[] | {id, message, priority, status, owner}'
```

### Get on-call participants
```bash
curl -sf "${OPSGENIE_URL}/v2/schedules/<schedule-id>/on-calls" \
  -H "Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}" | \
  jq '.data.onCallParticipants[] | {name, type}'
```

### Create an alert
```bash
curl -sf -X POST "${OPSGENIE_URL}/v2/alerts" \
  -H "Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "High CPU on prod-web-01",
    "priority": "P2",
    "description": "CPU usage exceeded 90% for 10 minutes",
    "tags": ["infrastructure", "cpu"]
  }' | jq '{requestId: .requestId}'
```

### Acknowledge an alert
```bash
curl -sf -X POST "${OPSGENIE_URL}/v2/alerts/<alert-id>/acknowledge" \
  -H "Authorization: GenieKey ${OTTO_OPSGENIE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"note":"Investigating"}' | jq '.result'
```
