#!/usr/bin/env bash
# OTTO - Fetch OpsGenie alerts, on-call, and schedules
# Outputs structured JSON to stdout
# Uses: curl + OTTO_OPSGENIE_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"open_alerts":[],"on_call":[],"schedules":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping OpsGenie fetch"
    echo "${empty_result}"
    exit 0
fi

OG_TOKEN="${OTTO_OPSGENIE_TOKEN:-}"
if [[ -z "${OG_TOKEN}" ]]; then
    log_warn "OTTO_OPSGENIE_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

OG_API="${OTTO_OPSGENIE_API:-https://api.opsgenie.com/v2}"

og_get() {
    curl -s --fail -H "Authorization: GenieKey ${OG_TOKEN}" "$1" 2>/dev/null
}

# Fetch open alerts
open_alerts="[]"
if response=$(og_get "${OG_API}/alerts?query=status%3Aopen&limit=50&sort=createdAt&order=desc"); then
    open_alerts=$(echo "${response}" | jq '[.data[]? | {
        id: .id,
        message: .message,
        status: .status,
        priority: .priority,
        source: .source,
        tags: .tags,
        created_at: .createdAt,
        updated_at: .updatedAt,
        acknowledged: .acknowledged,
        owner: (.owner // ""),
        count: .count
    }]' 2>/dev/null) || open_alerts="[]"
fi

# Fetch on-call for all schedules
on_call="[]"
schedules="[]"
if response=$(og_get "${OG_API}/schedules"); then
    schedules=$(echo "${response}" | jq '[.data[]? | {
        id: .id,
        name: .name,
        enabled: .enabled,
        owner_team: (.ownerTeam.name // null)
    }]' 2>/dev/null) || schedules="[]"

    schedule_ids=$(echo "${schedules}" | jq -r '.[].id // empty' 2>/dev/null) || schedule_ids=""
    on_call_list="[]"
    for sid in ${schedule_ids}; do
        if oc_response=$(og_get "${OG_API}/schedules/${sid}/on-calls"); then
            oc=$(echo "${oc_response}" | jq --arg sid "${sid}" '[.data.onCallParticipants[]? | {
                schedule_id: $sid,
                user: .name,
                type: .type
            }]' 2>/dev/null) || oc="[]"
            on_call_list=$(echo "${on_call_list}" | jq --argjson new "${oc}" '. + $new' 2>/dev/null) || true
        fi
    done
    on_call="${on_call_list}"
fi

jq -n \
    --argjson open_alerts "${open_alerts}" \
    --argjson on_call "${on_call}" \
    --argjson schedules "${schedules}" \
    '{
        open_alerts: $open_alerts,
        on_call: $on_call,
        schedules: $schedules
    }'
