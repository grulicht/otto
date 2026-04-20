#!/usr/bin/env bash
# OTTO - Fetch Wazuh SIEM agent status and alerts
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"agents_active":0,"agents_disconnected":0,"agents_total":0,"active_alerts":0,"alerts":[],"compliance_score":0}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Wazuh fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_WAZUH_URL:-}" || -z "${OTTO_WAZUH_USER:-}" || -z "${OTTO_WAZUH_PASS:-}" ]]; then
    log_debug "OTTO_WAZUH_URL, OTTO_WAZUH_USER, or OTTO_WAZUH_PASS not set, skipping Wazuh fetch"
    echo "${empty_result}"
    exit 0
fi

# Authenticate and get JWT token
token_raw=$(curl -s --max-time 15 -k -X POST "${OTTO_WAZUH_URL}/security/user/authenticate" \
    -u "${OTTO_WAZUH_USER}:${OTTO_WAZUH_PASS}" 2>/dev/null) || token_raw="{}"
token=$(echo "${token_raw}" | jq -r '.data.token // empty' 2>/dev/null) || token=""

if [[ -z "${token}" ]]; then
    log_debug "Wazuh authentication failed"
    echo "${empty_result}"
    exit 0
fi

wazuh_get() {
    curl -s --max-time 15 -k -X GET "${OTTO_WAZUH_URL}${1}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# Agent summary
agents_raw=$(wazuh_get "/agents/summary/status") || agents_raw="{}"
agents_active=$(echo "${agents_raw}" | jq '.data.connection.active // 0' 2>/dev/null) || agents_active=0
agents_disconnected=$(echo "${agents_raw}" | jq '.data.connection.disconnected // 0' 2>/dev/null) || agents_disconnected=0
agents_total=$(echo "${agents_raw}" | jq '.data.connection.total // 0' 2>/dev/null) || agents_total=0

# Recent alerts (last 24h, level >= 10)
alerts_raw=$(wazuh_get "/alerts?limit=20&sort=-timestamp&q=rule.level>=10") || alerts_raw="{}"
alerts=$(echo "${alerts_raw}" | jq '[(.data.affected_items // [])[] | {
    id: .id,
    timestamp: .timestamp,
    rule_id: .rule.id,
    rule_level: .rule.level,
    rule_description: .rule.description,
    agent_name: .agent.name
}]' 2>/dev/null) || alerts="[]"
active_alerts=$(echo "${alerts}" | jq 'length' 2>/dev/null) || active_alerts=0

# Compliance score (SCA)
sca_raw=$(wazuh_get "/sca") || sca_raw="{}"
compliance_score=$(echo "${sca_raw}" | jq '[(.data.affected_items // [])[] | .score] | if length > 0 then (add / length | floor) else 0 end' 2>/dev/null) || compliance_score=0

jq -n \
    --argjson agents_active "${agents_active}" \
    --argjson agents_disconnected "${agents_disconnected}" \
    --argjson agents_total "${agents_total}" \
    --argjson active_alerts "${active_alerts}" \
    --argjson alerts "${alerts}" \
    --argjson compliance_score "${compliance_score}" \
    '{
        agents_active: $agents_active,
        agents_disconnected: $agents_disconnected,
        agents_total: $agents_total,
        active_alerts: $active_alerts,
        alerts: $alerts,
        compliance_score: $compliance_score
    }'
