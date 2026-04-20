#!/usr/bin/env bash
# OTTO - Fetch Zabbix monitoring data via JSON-RPC API
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"triggers_active":0,"hosts_monitored":0,"problems_count":0,"problems":[]}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping Zabbix fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_ZABBIX_URL:-}" || -z "${OTTO_ZABBIX_TOKEN:-}" ]]; then
    log_debug "OTTO_ZABBIX_URL or OTTO_ZABBIX_TOKEN not set, skipping Zabbix fetch"
    echo "${empty_result}"
    exit 0
fi

API_URL="${OTTO_ZABBIX_URL}/api_jsonrpc.php"

zabbix_rpc() {
    local method="$1"
    local params="$2"
    curl -s --max-time 15 -X POST "${API_URL}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${OTTO_ZABBIX_TOKEN}" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" 2>/dev/null
}

# Active triggers count
triggers_active=$(zabbix_rpc "trigger.get" '{"countOutput":true,"filter":{"value":1},"monitored":true}' | jq -r '.result // 0' 2>/dev/null) || triggers_active=0

# Monitored hosts count
hosts_monitored=$(zabbix_rpc "host.get" '{"countOutput":true,"filter":{"status":0}}' | jq -r '.result // 0' 2>/dev/null) || hosts_monitored=0

# Current problems
problems_raw=$(zabbix_rpc "problem.get" '{"recent":true,"limit":20,"sortfield":"eventid","sortorder":"DESC"}' 2>/dev/null) || problems_raw="{}"
problems=$(echo "${problems_raw}" | jq '[(.result // [])[] | {
    eventid: .eventid,
    name: .name,
    severity: (.severity | tonumber),
    acknowledged: (.acknowledged | tostring),
    clock: .clock
}]' 2>/dev/null) || problems="[]"
problems_count=$(echo "${problems}" | jq 'length' 2>/dev/null) || problems_count=0

jq -n \
    --argjson triggers_active "${triggers_active}" \
    --argjson hosts_monitored "${hosts_monitored}" \
    --argjson problems_count "${problems_count}" \
    --argjson problems "${problems}" \
    '{
        triggers_active: $triggers_active,
        hosts_monitored: $hosts_monitored,
        problems_count: $problems_count,
        problems: $problems
    }'
