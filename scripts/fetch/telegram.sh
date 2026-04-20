#!/usr/bin/env bash
# OTTO - Fetch Telegram bot updates count
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"updates_count":0,"updates":[],"bot_info":{}}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Telegram fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_TELEGRAM_TOKEN:-}" ]]; then
    log_debug "OTTO_TELEGRAM_TOKEN not set, skipping Telegram fetch"
    echo "${empty_result}"
    exit 0
fi

TG_API="https://api.telegram.org/bot${OTTO_TELEGRAM_TOKEN}"

tg_get() {
    curl -s --max-time 15 "${TG_API}/${1}" 2>/dev/null
}

# Verify bot token
me_raw=$(tg_get "getMe") || me_raw="{}"
if [[ "$(echo "${me_raw}" | jq -r '.ok' 2>/dev/null)" != "true" ]]; then
    log_debug "Telegram bot auth failed"
    echo "${empty_result}"
    exit 0
fi

bot_info=$(echo "${me_raw}" | jq '{
    id: .result.id,
    username: .result.username,
    first_name: .result.first_name
}' 2>/dev/null) || bot_info="{}"

# Get pending updates
updates_raw=$(tg_get "getUpdates?limit=100&timeout=0") || updates_raw="{}"
updates=$(echo "${updates_raw}" | jq '[(.result // [])[] | {
    update_id: .update_id,
    chat_id: (.message.chat.id // .callback_query.message.chat.id // null),
    chat_title: (.message.chat.title // .message.chat.first_name // "unknown"),
    text: (.message.text // .callback_query.data // "" | .[0:200]),
    date: (.message.date // null)
}] | .[0:50]' 2>/dev/null) || updates="[]"
updates_count=$(echo "${updates}" | jq 'length' 2>/dev/null) || updates_count=0

jq -n \
    --argjson updates_count "${updates_count}" \
    --argjson updates "${updates}" \
    --argjson bot_info "${bot_info}" \
    '{
        updates_count: $updates_count,
        updates: $updates,
        bot_info: $bot_info
    }'
