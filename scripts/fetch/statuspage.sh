#!/usr/bin/env bash
# OTTO - Fetch StatusPage.io component statuses and incidents
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"components":[],"active_incidents":[],"active_incidents_count":0}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping StatusPage fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_STATUSPAGE_API_KEY:-}" || -z "${OTTO_STATUSPAGE_PAGE_ID:-}" ]]; then
    log_debug "OTTO_STATUSPAGE_API_KEY or OTTO_STATUSPAGE_PAGE_ID not set, skipping StatusPage fetch"
    echo "${empty_result}"
    exit 0
fi

SP_API="https://api.statuspage.io/v1/pages/${OTTO_STATUSPAGE_PAGE_ID}"

sp_get() {
    curl -s --max-time 15 -X GET "$1" \
        -H "Authorization: OAuth ${OTTO_STATUSPAGE_API_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Components
components_raw=$(sp_get "${SP_API}/components") || components_raw="[]"
components=$(echo "${components_raw}" | jq '[(.[] // []) | {
    id: .id,
    name: .name,
    status: .status,
    updated_at: .updated_at
}]' 2>/dev/null) || components="[]"

# Active incidents
incidents_raw=$(sp_get "${SP_API}/incidents/unresolved") || incidents_raw="[]"
active_incidents=$(echo "${incidents_raw}" | jq '[(.[] // []) | {
    id: .id,
    name: .name,
    status: .status,
    impact: .impact,
    created_at: .created_at,
    updated_at: .updated_at
}]' 2>/dev/null) || active_incidents="[]"
active_incidents_count=$(echo "${active_incidents}" | jq 'length' 2>/dev/null) || active_incidents_count=0

jq -n \
    --argjson components "${components}" \
    --argjson active_incidents "${active_incidents}" \
    --argjson active_incidents_count "${active_incidents_count}" \
    '{
        components: $components,
        active_incidents: $active_incidents,
        active_incidents_count: $active_incidents_count
    }'
