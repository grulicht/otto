---
name: telegram
description: Telegram Bot API for notifications and command handling
type: api
required_env:
  - OTTO_TELEGRAM_TOKEN
required_tools:
  - curl
  - jq
check_command: "curl -sf 'https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/getMe' | jq -r '.result.username'"
---

# Telegram

## Connection

OTTO connects to Telegram through the Bot API using a bot token obtained
from @BotFather. Optionally set `OTTO_TELEGRAM_CHAT_ID` to specify the default
chat/group for notifications.

```bash
curl -sf "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/<method>"
```

## Available Data

- **Messages**: Send text, formatted messages, and documents to chats
- **Updates**: Receive incoming messages and callback queries
- **Chats**: Get chat info and member lists
- **Inline keyboards**: Send interactive buttons for user input
- **Commands**: Register and handle bot commands
- **Files**: Send and receive documents, photos, and files
- **Notifications**: Alert delivery with configurable parse mode (HTML/Markdown)

## Common Queries

### Send a message
```bash
curl -sf -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"${OTTO_TELEGRAM_CHAT_ID}\",\"text\":\"Deployment complete\",\"parse_mode\":\"HTML\"}"
```

### Send a formatted alert
```bash
curl -sf -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"${OTTO_TELEGRAM_CHAT_ID}\",\"text\":\"<b>ALERT</b>: High CPU on prod-web-01\\n<i>Severity</i>: P2\",\"parse_mode\":\"HTML\"}"
```

### Get updates (recent messages to the bot)
```bash
curl -sf "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/getUpdates?limit=10" | \
  jq '.result[] | {update_id, message: .message.text, from: .message.from.username}'
```

### Get chat info
```bash
curl -sf "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/getChat?chat_id=${OTTO_TELEGRAM_CHAT_ID}" | \
  jq '.result | {id, title, type}'
```

### Send document
```bash
curl -sf -X POST "https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}/sendDocument" \
  -F "chat_id=${OTTO_TELEGRAM_CHAT_ID}" \
  -F "document=@/path/to/report.pdf" \
  -F "caption=Morning report"
```
