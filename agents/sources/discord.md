---
name: discord
description: Discord messaging via webhooks and Bot API for notifications
type: api
required_env:
  - OTTO_DISCORD_WEBHOOK_URL
required_tools:
  - curl
  - jq
check_command: "curl -sf '${OTTO_DISCORD_WEBHOOK_URL}' | jq -r '.name'"
---

# Discord

## Connection

OTTO connects to Discord primarily through Incoming Webhooks for sending messages.
For richer interactions, use a Bot Token with the Discord API.

### Webhook (simple notifications)
```bash
curl -sf -X POST "${OTTO_DISCORD_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{"content":"Message from OTTO"}'
```

### Bot API (full access)
Set `OTTO_DISCORD_BOT_TOKEN` for bot-level access.

```bash
curl -sf -H "Authorization: Bot ${OTTO_DISCORD_BOT_TOKEN}" \
  "https://discord.com/api/v10/users/@me" | jq '.username'
```

## Available Data

- **Messages**: Send messages, embeds, and files to channels
- **Embeds**: Rich formatted messages with fields, colors, and images
- **Channels**: List and manage guild channels (Bot API)
- **Guilds**: Server management (Bot API)
- **Threads**: Create and manage threads (Bot API)

## Common Queries

### Send a rich embed
```bash
curl -sf -X POST "${OTTO_DISCORD_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "embeds": [{
      "title": "Deployment Alert",
      "description": "myapp v1.2.3 deployed to production",
      "color": 3066993,
      "fields": [
        {"name": "Environment", "value": "production", "inline": true},
        {"name": "Status", "value": "success", "inline": true}
      ]
    }]
  }'
```

### List guild channels (Bot API)
```bash
curl -sf -H "Authorization: Bot ${OTTO_DISCORD_BOT_TOKEN}" \
  "https://discord.com/api/v10/guilds/<guild-id>/channels" | \
  jq '.[] | {id, name, type}'
```
