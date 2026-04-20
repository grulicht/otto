#!/usr/bin/env bash
# OTTO - Fetch Rocket.Chat unread messages and channel count
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"unread_messages":0,"channel_count":0,"channels_with_unread":[]}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Rocket.Chat fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_ROCKETCHAT_URL:-}" || -z "${OTTO_ROCKETCHAT_TOKEN:-}" || -z "${OTTO_ROCKETCHAT_USER_ID:-}" ]]; then
    log_debug "OTTO_ROCKETCHAT_URL, OTTO_ROCKETCHAT_TOKEN, or OTTO_ROCKETCHAT_USER_ID not set, skipping Rocket.Chat fetch"
    echo "${empty_result}"
    exit 0
fi

rc_get() {
    curl -s --max-time 15 -X GET "${OTTO_ROCKETCHAT_URL}/api/v1${1}" \
        -H "X-Auth-Token: ${OTTO_ROCKETCHAT_TOKEN}" \
        -H "X-User-Id: ${OTTO_ROCKETCHAT_USER_ID}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Verify connectivity
me_raw=$(rc_get "/me") || me_raw="{}"
if [[ "$(echo "${me_raw}" | jq -r '.success // false' 2>/dev/null)" != "true" ]]; then
    log_debug "Rocket.Chat auth failed"
    echo "${empty_result}"
    exit 0
fi

# Subscriptions (channels user is in)
subs_raw=$(rc_get "/subscriptions.getAll") || subs_raw="{}"
channels_with_unread=$(echo "${subs_raw}" | jq '[(.update // [])[] | select((.unread // 0) > 0) | {
    name: .name,
    type: .t,
    unread: .unread,
    user_mentions: (.userMentions // 0)
}] | sort_by(-.unread) | .[0:30]' 2>/dev/null) || channels_with_unread="[]"

unread_messages=$(echo "${channels_with_unread}" | jq '[.[].unread] | add // 0' 2>/dev/null) || unread_messages=0
channel_count=$(echo "${subs_raw}" | jq '(.update // []) | length' 2>/dev/null) || channel_count=0

jq -n \
    --argjson unread_messages "${unread_messages}" \
    --argjson channel_count "${channel_count}" \
    --argjson channels_with_unread "${channels_with_unread}" \
    '{
        unread_messages: $unread_messages,
        channel_count: $channel_count,
        channels_with_unread: $channels_with_unread
    }'
