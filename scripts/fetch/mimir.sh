#!/usr/bin/env bash
# OTTO - Fetch Grafana Mimir metrics backend stats
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"active_series":0,"tenant_stats":{},"ruler_status":"unknown","ready":false}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Mimir fetch"
    echo "${empty_result}"
    exit 0
fi

MIMIR_URL="${OTTO_MIMIR_URL:-http://localhost:8080}"
MIMIR_TENANT="${OTTO_MIMIR_TENANT:-}"
TENANT_HEADER=""
if [[ -n "${MIMIR_TENANT}" ]]; then
    TENANT_HEADER="-H X-Scope-OrgID:${MIMIR_TENANT}"
fi

mimir_get() {
    # shellcheck disable=SC2086
    curl -s --max-time 15 ${TENANT_HEADER} "${MIMIR_URL}${1}" 2>/dev/null
}

# Test connectivity
if ! mimir_get "/ready" 2>/dev/null | grep -qi "ready"; then
    log_debug "Cannot connect to Mimir at ${MIMIR_URL}"
    echo "${empty_result}"
    exit 0
fi

# Active series via stats
stats_raw=$(mimir_get "/api/v1/cardinality/label_names?limit=1") || stats_raw="{}"
active_series=$(echo "${stats_raw}" | jq '.data.cardinality // 0' 2>/dev/null) || active_series=0

# Tenant stats via distributor
tenant_raw=$(mimir_get "/distributor/all_user_stats") || tenant_raw="[]"
tenant_stats=$(echo "${tenant_raw}" | jq 'if type == "array" then
    [.[] | {user_id: .userID, ingestion_rate: .ingestionRate, num_series: .numSeries}] | .[0:20]
else {} end' 2>/dev/null) || tenant_stats="{}"

# Ruler status
ruler_raw=$(mimir_get "/ruler/ring") || ruler_raw="{}"
ruler_status="unknown"
if echo "${ruler_raw}" | jq -e '.shards' &>/dev/null; then
    ruler_status="active"
elif [[ -n "${ruler_raw}" && "${ruler_raw}" != "{}" ]]; then
    ruler_status="available"
fi

jq -n \
    --argjson active_series "${active_series}" \
    --argjson tenant_stats "${tenant_stats}" \
    --arg ruler_status "${ruler_status}" \
    --argjson ready true \
    '{
        active_series: $active_series,
        tenant_stats: $tenant_stats,
        ruler_status: $ruler_status,
        ready: $ready
    }'
