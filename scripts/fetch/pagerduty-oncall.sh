#!/usr/bin/env bash
# OTTO - Fetch PagerDuty on-call specific data
# Outputs structured JSON: current on-call users, upcoming overrides, escalation policies
# Uses: curl + OTTO_PAGERDUTY_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"current_oncall":[],"upcoming_overrides":[],"escalation_policies":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping PagerDuty on-call fetch"
    echo "${empty_result}"
    exit 0
fi

PD_TOKEN="${OTTO_PAGERDUTY_TOKEN:-}"
if [[ -z "${PD_TOKEN}" ]]; then
    log_warn "OTTO_PAGERDUTY_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

PD_API="https://api.pagerduty.com"

pd_get() {
    curl -s --fail -H "Authorization: Token token=${PD_TOKEN}" -H "Content-Type: application/json" "${PD_API}$1" 2>/dev/null
}

# Fetch current on-call users
current_oncall="[]"
if response=$(pd_get "/oncalls?limit=100&earliest=true"); then
    current_oncall=$(echo "${response}" | jq '[.oncalls[]? | {
        user_id: .user.id,
        user_name: .user.summary,
        user_email: .user.email,
        schedule_id: (.schedule.id // null),
        schedule_name: (.schedule.summary // "Direct Assignment"),
        escalation_policy_id: .escalation_policy.id,
        escalation_policy_name: .escalation_policy.summary,
        escalation_level: .escalation_level,
        start: .start,
        end: .end
    }] | unique_by(.user_id + .escalation_policy_id)' 2>/dev/null) || current_oncall="[]"
fi

# Fetch upcoming overrides across all schedules
upcoming_overrides="[]"
if schedules_response=$(pd_get "/schedules?limit=100"); then
    schedule_ids=$(echo "${schedules_response}" | jq -r '.schedules[]?.id // empty' 2>/dev/null || true)
    if [[ -n "${schedule_ids}" ]]; then
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        future=$(date -u -d "+7 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v+7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
        if [[ -n "${future}" ]]; then
            all_overrides="[]"
            while IFS= read -r sid; do
                [[ -z "${sid}" ]] && continue
                if override_response=$(pd_get "/schedules/${sid}/overrides?since=${now}&until=${future}"); then
                    schedule_overrides=$(echo "${override_response}" | jq --arg sched "${sid}" '[.overrides[]? | {
                        id: .id,
                        schedule_id: $sched,
                        user: .user.summary,
                        start: .start,
                        end: .end
                    }]' 2>/dev/null) || schedule_overrides="[]"
                    all_overrides=$(echo "${all_overrides}" | jq --argjson new "${schedule_overrides}" '. + $new' 2>/dev/null) || true
                fi
            done <<< "${schedule_ids}"
            upcoming_overrides="${all_overrides}"
        fi
    fi
fi

# Fetch escalation policies
escalation_policies="[]"
if response=$(pd_get "/escalation_policies?limit=100"); then
    escalation_policies=$(echo "${response}" | jq '[.escalation_policies[]? | {
        id: .id,
        name: .name,
        description: (.description // ""),
        num_loops: .num_loops,
        teams: [.teams[]?.summary],
        rules: [.escalation_rules[]? | {
            escalation_delay_in_minutes: .escalation_delay_in_minutes,
            targets: [.targets[]? | {type: .type, name: .summary}]
        }]
    }]' 2>/dev/null) || escalation_policies="[]"
fi

jq -n \
    --argjson current_oncall "${current_oncall}" \
    --argjson upcoming_overrides "${upcoming_overrides}" \
    --argjson escalation_policies "${escalation_policies}" \
    '{
        current_oncall: $current_oncall,
        upcoming_overrides: $upcoming_overrides,
        escalation_policies: $escalation_policies
    }'
