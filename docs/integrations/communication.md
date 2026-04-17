# Communication Integrations

OTTO supports multiple communication channels for notifications,
reports, and interactive commands.

## Slack

### Setup
1. Create a Slack App at https://api.slack.com/apps
2. Add Bot Token Scopes: `chat:write`, `channels:read`, `im:read`, `im:write`
3. Install the app to your workspace
4. Copy the Bot Token

```bash
# In ~/.config/otto/.env
OTTO_SLACK_TOKEN=xoxb-your-bot-token
OTTO_SLACK_CHANNEL_ID=C12345678
```

### Features
- Morning briefings with Block Kit formatting
- Alert notifications with severity indicators
- Night Watcher reports
- Task triage with emoji reactions
- Thread-based conversations

## Telegram

### Setup
1. Create a bot via @BotFather
2. Get the bot token
3. Get your chat ID (send /start, then check API)

```bash
OTTO_TELEGRAM_TOKEN=123456:ABC-DEF...
OTTO_TELEGRAM_CHAT_ID=your-chat-id
```

### Features
- MarkdownV2 formatted messages
- Alert notifications
- Morning reports

## RocketChat

### Setup
```bash
OTTO_ROCKETCHAT_URL=https://chat.example.com
OTTO_ROCKETCHAT_TOKEN=your-personal-access-token
OTTO_ROCKETCHAT_USER_ID=your-user-id
```

## Microsoft Teams

### Setup
Create an Incoming Webhook in your Teams channel.

```bash
OTTO_TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/...
```

### Features
- Adaptive Card formatted messages
- Alert notifications

## Discord

### Setup
1. Create a Discord Bot at https://discord.com/developers
2. Add to your server

```bash
OTTO_DISCORD_TOKEN=your-bot-token
OTTO_DISCORD_CHANNEL_ID=your-channel-id
```

### Features
- Embed formatted messages
- Alert notifications

## Email (SMTP)

### Setup
```bash
OTTO_SMTP_HOST=smtp.gmail.com
OTTO_SMTP_PORT=587
OTTO_SMTP_USER=your@email.com
OTTO_SMTP_PASS=app-password
OTTO_EMAIL_FROM=otto@example.com
OTTO_EMAIL_TO=you@example.com
```

### Features
- HTML formatted reports
- Morning briefings
- Critical alert emails

## Channel Priority

Configure in `config.yaml`:
```yaml
communication:
  primary: slack
  channels:
    slack:
      enabled: true
    telegram:
      enabled: true
```

Critical alerts are sent to all enabled channels.
Regular reports go to the primary channel only.
