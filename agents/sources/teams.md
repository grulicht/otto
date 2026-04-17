---
name: teams
description: Microsoft Teams via Graph API for notifications and channel management
type: api
required_env:
  - OTTO_TEAMS_WEBHOOK_URL
required_tools:
  - curl
  - jq
check_command: "curl -sf -o /dev/null -w '%{http_code}' -X POST '${OTTO_TEAMS_WEBHOOK_URL}' -H 'Content-Type: application/json' -d '{\"text\":\"OTTO health check\"}'"
---

# Microsoft Teams

## Connection

OTTO connects to Microsoft Teams primarily through Incoming Webhooks for sending
messages, and optionally through the Microsoft Graph API for richer interactions.

### Webhook (simple notifications)
```bash
curl -sf -X POST "${OTTO_TEAMS_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{"text":"Message from OTTO"}'
```

### Graph API (full access)
Requires an Azure AD app registration with appropriate permissions.
Set `OTTO_TEAMS_TENANT_ID`, `OTTO_TEAMS_CLIENT_ID`, and `OTTO_TEAMS_CLIENT_SECRET`.

```bash
token=$(curl -sf -X POST "https://login.microsoftonline.com/${OTTO_TEAMS_TENANT_ID}/oauth2/v2.0/token" \
  -d "client_id=${OTTO_TEAMS_CLIENT_ID}&scope=https://graph.microsoft.com/.default&client_secret=${OTTO_TEAMS_CLIENT_SECRET}&grant_type=client_credentials" | jq -r '.access_token')
```

## Available Data

- **Messages**: Send messages to channels via webhook or Graph API
- **Adaptive Cards**: Rich formatted messages with actions
- **Channels**: List and manage team channels (Graph API)
- **Teams**: List teams and members (Graph API)

## Common Queries

### Send an Adaptive Card
```bash
curl -sf -X POST "${OTTO_TEAMS_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "message",
    "attachments": [{
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [{"type": "TextBlock", "text": "**Incident**: High CPU on prod-web-01", "wrap": true}]
      }
    }]
  }'
```

### List teams (Graph API)
```bash
curl -sf -H "Authorization: Bearer ${token}" \
  "https://graph.microsoft.com/v1.0/teams" | jq '.value[] | {id, displayName}'
```
