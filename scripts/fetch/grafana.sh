#!/usr/bin/env bash
# OTTO - Fetch Grafana alerts
# Outputs structured JSON to stdout
# Requires: OTTO_GRAFANA_URL and OTTO_GRAFANA_TOKEN environment variables
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"firing_alerts":[],"pending_alerts":[],"silenced_count":0}'

# Check for curl
if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Grafana fetch"
    echo "${empty_result}"
    exit 0
fi

# Check for required environment variables
GRAFANA_URL="${OTTO_GRAFANA_URL:-}"
GRAFANA_TOKEN="${OTTO_GRAFANA_TOKEN:-}"

if [[ -z "${GRAFANA_URL}" ]] || [[ -z "${GRAFANA_TOKEN}" ]]; then
    log_debug "OTTO_GRAFANA_URL or OTTO_GRAFANA_TOKEN not set, skipping Grafana fetch"
    echo "${empty_result}"
    exit 0
fi

# Remove trailing slash from URL
GRAFANA_URL="${GRAFANA_URL%/}"

# Helper: authenticated GET request to Grafana API
grafana_get() {
    local endpoint="$1"
    curl -sf --max-time 15 \
        -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
        -H "Content-Type: application/json" \
        "${GRAFANA_URL}${endpoint}" 2>/dev/null
}

# Fetch alert rules via Grafana Alerting API (unified alerting)
firing_alerts="[]"
pending_alerts="[]"
silenced_count=0

# Try unified alerting API first (Grafana 9+)
if alerts_response=$(grafana_get "/api/prometheus/grafana/api/v1/alerts"); then
    firing_alerts=$(echo "${alerts_response}" | jq '[
        .data.alerts // [] | .[] | select(.state == "firing") | {
            name: .labels.alertname,
            state: .state,
            severity: (.labels.severity // "unknown"),
            summary: (.annotations.summary // .annotations.description // ""),
            instance: (.labels.instance // ""),
            active_since: .activeAt,
            value: (.value // "")
        }
    ]' 2>/dev/null) || firing_alerts="[]"

    pending_alerts=$(echo "${alerts_response}" | jq '[
        .data.alerts // [] | .[] | select(.state == "pending") | {
            name: .labels.alertname,
            state: .state,
            severity: (.labels.severity // "unknown"),
            summary: (.annotations.summary // .annotations.description // ""),
            instance: (.labels.instance // ""),
            active_since: .activeAt
        }
    ]' 2>/dev/null) || pending_alerts="[]"

# Fallback: legacy alerting API
elif alerts_response=$(grafana_get "/api/alerts"); then
    firing_alerts=$(echo "${alerts_response}" | jq '[
        .[] | select(.state == "alerting") | {
            name: .name,
            state: .state,
            severity: "unknown",
            summary: (.message // ""),
            dashboard: .dashboardSlug,
            panel_id: .panelId
        }
    ]' 2>/dev/null) || firing_alerts="[]"

    pending_alerts=$(echo "${alerts_response}" | jq '[
        .[] | select(.state == "pending") | {
            name: .name,
            state: .state,
            severity: "unknown",
            summary: (.message // "")
        }
    ]' 2>/dev/null) || pending_alerts="[]"
else
    log_warn "Failed to fetch Grafana alerts"
fi

# Fetch silences
if silences_response=$(grafana_get "/api/alertmanager/grafana/api/v2/silences"); then
    silenced_count=$(echo "${silences_response}" | jq '[.[] | select(.status.state == "active")] | length' 2>/dev/null) || silenced_count=0
fi

# Assemble final JSON
jq -n \
    --argjson firing "${firing_alerts}" \
    --argjson pending "${pending_alerts}" \
    --argjson silenced "${silenced_count}" \
    '{
        firing_alerts: $firing,
        pending_alerts: $pending,
        silenced_count: $silenced
    }'
