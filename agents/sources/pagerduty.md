---
name: pagerduty
description: PagerDuty incident management and on-call scheduling via REST API
type: api
required_env:
  - OTTO_PAGERDUTY_API_KEY
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}' 'https://api.pagerduty.com/abilities' | jq -r '.abilities[0]'"
---

# PagerDuty

## Connection

OTTO connects to PagerDuty through the REST API v2 using an API key (read-only
or full-access) or OAuth token.

```bash
curl -sf "https://api.pagerduty.com/<endpoint>" \
  -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json"
```

## Available Data

- **Incidents**: List, create, acknowledge, and resolve incidents
- **Services**: Service catalog and status
- **On-call**: Current on-call schedules and escalation policies
- **Users**: User directory and contact methods
- **Alerts**: Alert grouping and suppression
- **Analytics**: Incident analytics and metrics

## Common Queries

### List triggered incidents
```bash
curl -sf "https://api.pagerduty.com/incidents?statuses[]=triggered&statuses[]=acknowledged" \
  -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" | \
  jq '.incidents[] | {id, title, status, urgency, service: .service.summary}'
```

### Get current on-call
```bash
curl -sf "https://api.pagerduty.com/oncalls?earliest=true" \
  -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" | \
  jq '.oncalls[] | {user: .user.summary, schedule: .schedule.summary, escalation_level}'
```

### Trigger an incident
```bash
curl -sf -X POST "https://api.pagerduty.com/incidents" \
  -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "From: otto@example.com" \
  -d '{
    "incident": {
      "type": "incident",
      "title": "High CPU on prod-web-01",
      "service": {"id": "<service-id>", "type": "service_reference"},
      "urgency": "high"
    }
  }' | jq '{id: .incident.id, status: .incident.status}'
```

### Acknowledge an incident
```bash
curl -sf -X PUT "https://api.pagerduty.com/incidents" \
  -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "From: otto@example.com" \
  -d '{"incidents":[{"id":"<incident-id>","type":"incident_reference","status":"acknowledged"}]}' | \
  jq '.incidents[].status'
```
