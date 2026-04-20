#!/usr/bin/env bash
# OTTO - Fetch PagerDuty incidents, on-call, and alerts
# Outputs structured JSON to stdout
# Uses: curl + OTTO_PAGERDUTY_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"active_incidents":[],"on_call":[],"triggered_alerts":[]}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping PagerDuty fetch"
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

# Fetch active incidents (triggered + acknowledged)
active_incidents="[]"
if response=$(pd_get "/incidents?statuses%5B%5D=triggered&statuses%5B%5D=acknowledged&limit=50&sort_by=created_at%3Adesc"); then
    active_incidents=$(echo "${response}" | jq '[.incidents[]? | {
        id: .id,
        title: .title,
        status: .status,
        urgency: .urgency,
        service: .service.summary,
        created_at: .created_at,
        updated_at: .updated_at,
        assignees: [.assignments[]?.assignee.summary],
        html_url: .html_url
    }]' 2>/dev/null) || active_incidents="[]"
fi

# Fetch on-call
on_call="[]"
if response=$(pd_get "/oncalls?limit=50&earliest=true"); then
    on_call=$(echo "${response}" | jq '[.oncalls[]? | {
        user: .user.summary,
        user_email: .user.email,
        schedule: (.schedule.summary // "Direct"),
        escalation_policy: .escalation_policy.summary,
        escalation_level: .escalation_level,
        start: .start,
        end: .end
    }] | unique_by(.user + .escalation_policy)' 2>/dev/null) || on_call="[]"
fi

# Fetch triggered alerts
triggered_alerts="[]"
if response=$(pd_get "/alerts?statuses%5B%5D=triggered&limit=50&sort_by=created_at%3Adesc"); then
    triggered_alerts=$(echo "${response}" | jq '[.alerts[]? | {
        id: .id,
        summary: .summary,
        severity: .severity,
        status: .status,
        service: .service.summary,
        created_at: .created_at,
        html_url: .html_url
    }]' 2>/dev/null) || triggered_alerts="[]"
fi

jq -n \
    --argjson active_incidents "${active_incidents}" \
    --argjson on_call "${on_call}" \
    --argjson triggered_alerts "${triggered_alerts}" \
    '{
        active_incidents: $active_incidents,
        on_call: $on_call,
        triggered_alerts: $triggered_alerts
    }'
