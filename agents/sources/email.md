---
name: email
description: Email notifications via SMTP or Gmail API
type: api
required_env:
  - OTTO_EMAIL_TO
required_tools:
  - curl
check_command: "echo 'Email source configured for ${OTTO_EMAIL_TO}'"
---

# Email

## Connection

OTTO sends email notifications via SMTP (using curl or sendmail) or the Gmail API.

### SMTP via curl
Set `OTTO_SMTP_HOST`, `OTTO_SMTP_PORT`, `OTTO_SMTP_USER`, `OTTO_SMTP_PASSWORD`,
and `OTTO_EMAIL_FROM`.

```bash
curl -sf --url "smtp://${OTTO_SMTP_HOST}:${OTTO_SMTP_PORT}" \
  --ssl-reqd \
  --mail-from "${OTTO_EMAIL_FROM}" \
  --mail-rcpt "${OTTO_EMAIL_TO}" \
  --user "${OTTO_SMTP_USER}:${OTTO_SMTP_PASSWORD}" \
  -T - <<EOF
From: ${OTTO_EMAIL_FROM}
To: ${OTTO_EMAIL_TO}
Subject: OTTO Alert

Alert message body here.
EOF
```

### Gmail API
Set `OTTO_GMAIL_TOKEN` for OAuth2 access.

```bash
curl -sf -X POST "https://gmail.googleapis.com/gmail/v1/users/me/messages/send" \
  -H "Authorization: Bearer ${OTTO_GMAIL_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"raw":"<base64-encoded-email>"}'
```

## Available Data

- **Send**: Plain text and HTML emails
- **Attachments**: Send files as attachments (SMTP)
- **Gmail**: Read inbox, search messages, manage labels (Gmail API)

## Common Queries

### Send a simple alert email
```bash
message="From: ${OTTO_EMAIL_FROM}\nTo: ${OTTO_EMAIL_TO}\nSubject: [OTTO] Alert: High CPU\n\nCPU usage exceeded 90% on prod-web-01."
echo -e "${message}" | curl -sf --url "smtp://${OTTO_SMTP_HOST}:${OTTO_SMTP_PORT}" \
  --ssl-reqd --mail-from "${OTTO_EMAIL_FROM}" --mail-rcpt "${OTTO_EMAIL_TO}" \
  --user "${OTTO_SMTP_USER}:${OTTO_SMTP_PASSWORD}" -T -
```

### Search Gmail (Gmail API)
```bash
curl -sf -H "Authorization: Bearer ${OTTO_GMAIL_TOKEN}" \
  "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=subject:alert+is:unread&maxResults=10" | \
  jq '.messages[]'
```
