---
name: pagerduty-oncall
description: PagerDuty on-call schedule integration for team management
type: api
required_env:
  - OTTO_PAGERDUTY_API_KEY
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}' 'https://api.pagerduty.com/users/me' | jq -r '.user.name'"
---

# PagerDuty On-Call

## Connection

OTTO connects to PagerDuty through the REST API v2 using an API token.
The token should have read access to schedules and on-call information.

```bash
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json" \
  "https://api.pagerduty.com/<endpoint>"
```

## Available Data

- **On-Calls**: Current on-call users for schedules and escalation policies
- **Schedules**: Schedule definitions, overrides, and rotations
- **Escalation Policies**: Who gets notified and in what order
- **Users**: User details and contact methods
- **Incidents**: Open and recent incidents

## Common Queries

### Get current on-call for a schedule
```bash
SCHEDULE_ID="PXXXXXX"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  "https://api.pagerduty.com/oncalls?schedule_ids[]=${SCHEDULE_ID}&since=${NOW}&until=${NOW}" | \
  jq '.oncalls[] | {user: .user.summary, email: .user.email, schedule: .schedule.summary}'
```

### List all schedules
```bash
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  "https://api.pagerduty.com/schedules?limit=100" | \
  jq '.schedules[] | {id, name: .summary}'
```

### Get schedule details
```bash
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  "https://api.pagerduty.com/schedules/${SCHEDULE_ID}" | \
  jq '.schedule | {name: .summary, time_zone, users: [.users[].summary]}'
```

### Get escalation policy
```bash
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  "https://api.pagerduty.com/escalation_policies/${POLICY_ID}" | \
  jq '.escalation_policy | {name: .summary, rules: [.escalation_rules[] | {targets: [.targets[].summary]}]}'
```

### List open incidents
```bash
curl -sf -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  "https://api.pagerduty.com/incidents?statuses[]=triggered&statuses[]=acknowledged&limit=25" | \
  jq '.incidents[] | {id, title, status, urgency, created_at, assigned_to: [.assignments[].assignee.summary]}'
```

### Create an override on a schedule
```bash
curl -sf -X POST -H "Authorization: Token token=${OTTO_PAGERDUTY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "override": {
      "start": "2024-01-15T09:00:00Z",
      "end": "2024-01-16T09:00:00Z",
      "user": {"id": "PXXXXXX", "type": "user_reference"}
    }
  }' \
  "https://api.pagerduty.com/schedules/${SCHEDULE_ID}/overrides"
```

## Integration with team.sh

This source is used by `team_get_oncall()` when `oncall.type` is set to `pagerduty`
in the team configuration. Required team config fields:

```yaml
team:
  oncall:
    type: pagerduty
    pagerduty_schedule_id: "PXXXXXX"
```

The `OTTO_PAGERDUTY_API_KEY` environment variable must be set in `~/.config/otto/.env`.
