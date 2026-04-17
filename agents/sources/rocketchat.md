---
name: rocketchat
description: RocketChat messaging platform via REST API for notifications and channel management
type: api
required_env:
  - OTTO_ROCKETCHAT_URL
  - OTTO_ROCKETCHAT_USER
  - OTTO_ROCKETCHAT_PASSWORD
required_tools:
  - curl
  - jq
check_command: "curl -sf '${OTTO_ROCKETCHAT_URL}/api/v1/info' | jq -r '.info.version'"
---

# RocketChat

## Connection

OTTO connects to RocketChat through the REST API. Authentication uses username/password
to obtain an auth token and user ID, which are then used for subsequent requests.

```bash
# Authenticate and get token
auth=$(curl -sf -X POST "${OTTO_ROCKETCHAT_URL}/api/v1/login" \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"${OTTO_ROCKETCHAT_USER}\",\"password\":\"${OTTO_ROCKETCHAT_PASSWORD}\"}")
token=$(echo "${auth}" | jq -r '.data.authToken')
user_id=$(echo "${auth}" | jq -r '.data.userId')
```

All subsequent requests require these headers:
- `X-Auth-Token: <token>`
- `X-User-Id: <user_id>`

## Available Data

- **Messages**: Post messages, reply to threads, pin and star messages
- **Channels**: List, create, archive, and manage channels
- **Users**: List users, get user info, set status
- **Groups**: Private group management
- **Direct Messages**: Send and manage DMs
- **Files**: Upload and share files
- **Subscriptions**: Manage channel subscriptions

## Common Queries

### Post a message
```bash
curl -sf -X POST "${OTTO_ROCKETCHAT_URL}/api/v1/chat.sendMessage" \
  -H "X-Auth-Token: ${token}" -H "X-User-Id: ${user_id}" \
  -H "Content-Type: application/json" \
  -d '{"message":{"rid":"<channel-id>","msg":"Deployment complete"}}' | jq '.message.msg'
```

### List channels
```bash
curl -sf "${OTTO_ROCKETCHAT_URL}/api/v1/channels.list?count=50" \
  -H "X-Auth-Token: ${token}" -H "X-User-Id: ${user_id}" | \
  jq '.channels[] | {id: ._id, name}'
```

### Get channel history
```bash
curl -sf "${OTTO_ROCKETCHAT_URL}/api/v1/channels.history?roomId=<channel-id>&count=20" \
  -H "X-Auth-Token: ${token}" -H "X-User-Id: ${user_id}" | \
  jq '.messages[] | {user: .u.username, msg, ts}'
```
