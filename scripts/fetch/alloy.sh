#!/usr/bin/env bash
# OTTO - Fetch Grafana Alloy telemetry pipeline status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"components_running":0,"components":[],"pipeline_health":"unknown","ready":false}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Alloy fetch"
    echo "${empty_result}"
    exit 0
fi

ALLOY_URL="${OTTO_ALLOY_URL:-http://localhost:12345}"

alloy_get() {
    curl -s --max-time 15 "${ALLOY_URL}${1}" 2>/dev/null
}

# Test connectivity
if ! alloy_get "/-/ready" 2>/dev/null | grep -qi "ready"; then
    log_debug "Cannot connect to Grafana Alloy at ${ALLOY_URL}"
    echo "${empty_result}"
    exit 0
fi

# Components status
components_raw=$(alloy_get "/api/v0/web/components") || components_raw="{}"
components=$(echo "${components_raw}" | jq '[(.components // [])[] | {
    id: .localID,
    label: .label,
    health: .health.type,
    module_id: .moduleID
}]' 2>/dev/null) || components="[]"
components_running=$(echo "${components}" | jq '[.[] | select(.health == "healthy")] | length' 2>/dev/null) || components_running=0

# Pipeline health summary
total=$(echo "${components}" | jq 'length' 2>/dev/null) || total=0
unhealthy=$(echo "${components}" | jq '[.[] | select(.health != "healthy")] | length' 2>/dev/null) || unhealthy=0
if [[ "${total}" -eq 0 ]]; then
    pipeline_health="unknown"
elif [[ "${unhealthy}" -eq 0 ]]; then
    pipeline_health="healthy"
elif [[ "${unhealthy}" -lt "${total}" ]]; then
    pipeline_health="degraded"
else
    pipeline_health="unhealthy"
fi

jq -n \
    --argjson components_running "${components_running}" \
    --argjson components "${components}" \
    --arg pipeline_health "${pipeline_health}" \
    --argjson ready true \
    '{
        components_running: $components_running,
        components: $components,
        pipeline_health: $pipeline_health,
        ready: $ready
    }'
