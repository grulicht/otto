#!/usr/bin/env bash
# OTTO - Fetch Microsoft Teams pending messages via Graph API
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"pending_messages":0,"chats":[],"webhook_available":false}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Teams fetch"
    echo "${empty_result}"
    exit 0
fi

# Webhook mode (simple notification check)
if [[ -n "${OTTO_TEAMS_WEBHOOK_URL:-}" ]]; then
    # Webhook URLs are write-only, we can only verify it exists
    jq -n \
        --argjson pending_messages 0 \
        --argjson chats "[]" \
        --argjson webhook_available true \
        '{
            pending_messages: $pending_messages,
            chats: $chats,
            webhook_available: $webhook_available
        }'
    exit 0
fi

# Graph API mode
if [[ -z "${OTTO_TEAMS_ACCESS_TOKEN:-}" ]]; then
    log_debug "OTTO_TEAMS_WEBHOOK_URL or OTTO_TEAMS_ACCESS_TOKEN not set, skipping Teams fetch"
    echo "${empty_result}"
    exit 0
fi

GRAPH_API="https://graph.microsoft.com/v1.0"

graph_get() {
    curl -s --max-time 15 -X GET "${GRAPH_API}${1}" \
        -H "Authorization: Bearer ${OTTO_TEAMS_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Chats with unread
chats_raw=$(graph_get "/me/chats?\$expand=lastMessagePreview&\$top=50") || chats_raw="{}"
chats=$(echo "${chats_raw}" | jq '[(.value // [])[] | select(.unreadCount // 0 > 0) | {
    id: .id,
    topic: (.topic // "Direct message"),
    chat_type: .chatType,
    unread_count: .unreadCount,
    last_message: (.lastMessagePreview.body.content // "" | .[0:200])
}] | .[0:30]' 2>/dev/null) || chats="[]"

pending_messages=$(echo "${chats}" | jq '[.[].unread_count] | add // 0' 2>/dev/null) || pending_messages=0

jq -n \
    --argjson pending_messages "${pending_messages}" \
    --argjson chats "${chats}" \
    --argjson webhook_available false \
    '{
        pending_messages: $pending_messages,
        chats: $chats,
        webhook_available: $webhook_available
    }'
