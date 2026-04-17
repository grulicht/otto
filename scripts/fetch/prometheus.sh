#!/usr/bin/env bash
# OTTO - Fetch Prometheus health and targets
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"up":false,"targets_up":0,"targets_down":0,"active_alerts":0,"rules_loaded":0}'

PROMETHEUS_URL="${OTTO_PROMETHEUS_URL:-http://localhost:9090}"

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Prometheus fetch"
    echo "${empty_result}"
    exit 0
fi

# Health check
up=false
if curl -sf "${PROMETHEUS_URL}/-/healthy" &>/dev/null; then
    up=true
fi

if [[ "${up}" == "false" ]]; then
    log_warn "Prometheus is not reachable at ${PROMETHEUS_URL}"
    echo "${empty_result}"
    exit 0
fi

# Targets
targets_up=0
targets_down=0
if targets_json=$(curl -sf "${PROMETHEUS_URL}/api/v1/targets" 2>/dev/null); then
    targets_up=$(echo "${targets_json}" | jq '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null) || targets_up=0
    targets_down=$(echo "${targets_json}" | jq '[.data.activeTargets[] | select(.health == "down")] | length' 2>/dev/null) || targets_down=0
fi

# Active alerts
active_alerts=0
if alerts_json=$(curl -sf "${PROMETHEUS_URL}/api/v1/alerts" 2>/dev/null); then
    active_alerts=$(echo "${alerts_json}" | jq '[.data.alerts[] | select(.state == "firing")] | length' 2>/dev/null) || active_alerts=0
fi

# Rules
rules_loaded=0
if rules_json=$(curl -sf "${PROMETHEUS_URL}/api/v1/rules" 2>/dev/null); then
    rules_loaded=$(echo "${rules_json}" | jq '[.data.groups[].rules[]] | length' 2>/dev/null) || rules_loaded=0
fi

jq -n \
    --argjson up "${up}" \
    --argjson tup "${targets_up}" \
    --argjson tdown "${targets_down}" \
    --argjson alerts "${active_alerts}" \
    --argjson rules "${rules_loaded}" \
    '{
        up: $up,
        targets_up: $tup,
        targets_down: $tdown,
        active_alerts: $alerts,
        rules_loaded: $rules
    }'
