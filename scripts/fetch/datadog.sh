#!/usr/bin/env bash
# OTTO - Fetch Datadog monitoring data
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"monitors_triggered":0,"monitors":[],"hosts_count":0,"apm_services":[]}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Datadog fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_DATADOG_API_KEY:-}" || -z "${OTTO_DATADOG_APP_KEY:-}" ]]; then
    log_debug "OTTO_DATADOG_API_KEY or OTTO_DATADOG_APP_KEY not set, skipping Datadog fetch"
    echo "${empty_result}"
    exit 0
fi

DD_SITE="${OTTO_DATADOG_SITE:-datadoghq.com}"
DD_API="https://api.${DD_SITE}/api/v1"

dd_get() {
    curl -s --max-time 15 -X GET "$1" \
        -H "DD-API-KEY: ${OTTO_DATADOG_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${OTTO_DATADOG_APP_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Triggered monitors
monitors_raw=$(dd_get "${DD_API}/monitor?monitor_tags=&page=0&page_size=50&query=status%3AAlert") || monitors_raw="[]"
monitors=$(echo "${monitors_raw}" | jq '[.[] | {
    id: .id,
    name: .name,
    status: (.overall_state // "unknown"),
    type: .type,
    message: (.message | .[0:200] // "")
}] // []' 2>/dev/null) || monitors="[]"
monitors_triggered=$(echo "${monitors}" | jq 'length' 2>/dev/null) || monitors_triggered=0

# Hosts count
hosts_raw=$(dd_get "${DD_API}/hosts/totals") || hosts_raw="{}"
hosts_count=$(echo "${hosts_raw}" | jq '.total_active // 0' 2>/dev/null) || hosts_count=0

# APM services
apm_raw=$(dd_get "https://api.${DD_SITE}/api/v2/services?page[limit]=50") || apm_raw="{}"
apm_services=$(echo "${apm_raw}" | jq '[(.data // [])[] | {
    name: .attributes.schema.dd_service,
    type: .attributes.schema.type
}]' 2>/dev/null) || apm_services="[]"

jq -n \
    --argjson monitors_triggered "${monitors_triggered}" \
    --argjson monitors "${monitors}" \
    --argjson hosts_count "${hosts_count}" \
    --argjson apm_services "${apm_services}" \
    '{
        monitors_triggered: $monitors_triggered,
        monitors: $monitors,
        hosts_count: $hosts_count,
        apm_services: $apm_services
    }'
