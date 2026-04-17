---
name: slack
description: Slack messaging platform via Web API for notifications and channel management
type: api
required_env:
  - OTTO_SLACK_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf -H 'Authorization: Bearer ${OTTO_SLACK_TOKEN}' 'https://slack.com/api/auth.test' | jq -r '.user'"
---

# Slack

## Connection

OTTO connects to Slack through the Web API using a Bot User OAuth Token.
The token should have scopes appropriate for the actions OTTO needs to perform
(typically: `chat:write`, `channels:read`, `channels:history`, `users:read`).

```bash
curl -sf -X POST -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"channel":"<channel-id>","text":"message"}' \
  "https://slack.com/api/<method>"
```

When the Slack MCP server is connected, prefer its tools over raw API calls.

## Available Data

- **Messages**: Post messages, reply to threads, update and delete messages
- **Channels**: List channels, get channel history, manage channel membership
- **Users**: List users, get user info and presence
- **Reactions**: Add and list emoji reactions
- **Files**: Upload and share files
- **Conversations**: Search messages across channels
- **Reminders**: Set and manage reminders
- **User groups**: Manage user groups and mentions

## Common Queries

### Post a message
```bash
curl -sf -X POST -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"channel":"#ops-alerts","text":"Deployment complete for myapp v1.2.3"}' \
  "https://slack.com/api/chat.postMessage" | jq '.ok'
```

### Post a rich message with blocks
```bash
curl -sf -X POST -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"channel":"#ops-alerts","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*Incident*: High CPU on prod-web-01\n*Severity*: P2\n*Status*: Investigating"}}]}' \
  "https://slack.com/api/chat.postMessage"
```

### List channels
```bash
curl -sf -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  "https://slack.com/api/conversations.list?types=public_channel&limit=100" | \
  jq '.channels[] | {id, name}'
```

### Get recent channel messages
```bash
curl -sf -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  "https://slack.com/api/conversations.history?channel=<channel-id>&limit=20" | \
  jq '.messages[] | {user, text, ts}'
```

### Search messages
```bash
curl -sf -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
  "https://slack.com/api/search.messages?query=deployment+failed&count=10" | \
  jq '.messages.matches[] | {text, channel: .channel.name}'
```
