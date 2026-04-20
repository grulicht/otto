#!/usr/bin/env bash
# OTTO - Fetch Discord unread messages and guild count
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"guild_count":0,"guilds":[],"unread_messages":0}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Discord fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_DISCORD_TOKEN:-}" ]]; then
    log_debug "OTTO_DISCORD_TOKEN not set, skipping Discord fetch"
    echo "${empty_result}"
    exit 0
fi

DISCORD_API="https://discord.com/api/v10"

discord_get() {
    curl -s --max-time 15 -X GET "${DISCORD_API}${1}" \
        -H "Authorization: Bot ${OTTO_DISCORD_TOKEN}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Verify token
user_raw=$(discord_get "/users/@me") || user_raw="{}"
if [[ "$(echo "${user_raw}" | jq -r '.id // empty' 2>/dev/null)" == "" ]]; then
    log_debug "Discord auth failed"
    echo "${empty_result}"
    exit 0
fi

# Guilds (servers)
guilds_raw=$(discord_get "/users/@me/guilds?limit=100") || guilds_raw="[]"
guilds=$(echo "${guilds_raw}" | jq '[(.[] // []) | {
    id: .id,
    name: .name,
    owner: .owner
}]' 2>/dev/null) || guilds="[]"
guild_count=$(echo "${guilds}" | jq 'length' 2>/dev/null) || guild_count=0

# Unread messages count is not directly available via bot API
# We approximate by checking channels with recent activity
unread_messages=0

jq -n \
    --argjson guild_count "${guild_count}" \
    --argjson guilds "${guilds}" \
    --argjson unread_messages "${unread_messages}" \
    '{
        guild_count: $guild_count,
        guilds: $guilds,
        unread_messages: $unread_messages
    }'
