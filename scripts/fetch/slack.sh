#!/usr/bin/env bash
# OTTO - Fetch Slack unread messages and mentions
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"unread_dm_count":0,"mentions_count":0,"channels_with_unread":[]}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Slack fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_SLACK_TOKEN:-}" ]]; then
    log_debug "OTTO_SLACK_TOKEN not set, skipping Slack fetch"
    echo "${empty_result}"
    exit 0
fi

slack_get() {
    curl -s --max-time 15 -X GET "$1" \
        -H "Authorization: Bearer ${OTTO_SLACK_TOKEN}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Verify token
auth_test=$(slack_get "https://slack.com/api/auth.test") || auth_test="{}"
if [[ "$(echo "${auth_test}" | jq -r '.ok' 2>/dev/null)" != "true" ]]; then
    log_debug "Slack auth failed"
    echo "${empty_result}"
    exit 0
fi

# Conversations list with unread
convos_raw=$(slack_get "https://slack.com/api/conversations.list?types=im,mpim,public_channel,private_channel&exclude_archived=true&limit=200") || convos_raw="{}"

# Unread DMs
unread_dm_count=$(echo "${convos_raw}" | jq '[(.channels // [])[] | select(.is_im == true and .is_user_deleted == false and (.unread_count_display // 0) > 0)] | length' 2>/dev/null) || unread_dm_count=0

# Channels with unread + mention counts
channels_with_unread=$(echo "${convos_raw}" | jq '[(.channels // [])[] | select((.unread_count_display // 0) > 0) | {
    id: .id,
    name: (.name // .user // "dm"),
    unread_count: .unread_count_display,
    mention_count: (.mention_count_display // 0)
}] | sort_by(-.mention_count) | .[0:30]' 2>/dev/null) || channels_with_unread="[]"

mentions_count=$(echo "${channels_with_unread}" | jq '[.[].mention_count] | add // 0' 2>/dev/null) || mentions_count=0

jq -n \
    --argjson unread_dm_count "${unread_dm_count}" \
    --argjson mentions_count "${mentions_count}" \
    --argjson channels_with_unread "${channels_with_unread}" \
    '{
        unread_dm_count: $unread_dm_count,
        mentions_count: $mentions_count,
        channels_with_unread: $channels_with_unread
    }'
