#!/usr/bin/env bash
# OTTO - Fetch New Relic monitoring data
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"violations":[],"violations_count":0,"alert_policies_active":0,"slo_compliance":[]}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping New Relic fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${OTTO_NEWRELIC_API_KEY:-}" || -z "${OTTO_NEWRELIC_ACCOUNT_ID:-}" ]]; then
    log_debug "OTTO_NEWRELIC_API_KEY or OTTO_NEWRELIC_ACCOUNT_ID not set, skipping New Relic fetch"
    echo "${empty_result}"
    exit 0
fi

NR_API="https://api.newrelic.com"

nr_gql() {
    local query="$1"
    curl -s --max-time 15 -X POST "${NR_API}/graphql" \
        -H "API-Key: ${OTTO_NEWRELIC_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\":\"${query}\"}" 2>/dev/null
}

nr_get() {
    curl -s --max-time 15 -X GET "$1" \
        -H "Api-Key: ${OTTO_NEWRELIC_API_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null
}

# NRQL violations (open incidents)
violations_raw=$(nr_get "${NR_API}/v2/alerts_violations.json?only_open=true") || violations_raw="{}"
violations=$(echo "${violations_raw}" | jq '[(.violations // [])[] | {
    id: .id,
    label: .label,
    priority: .priority,
    opened_at: .opened_at,
    entity_name: (.links.condition_name // "unknown")
}] | .[0:30]' 2>/dev/null) || violations="[]"
violations_count=$(echo "${violations}" | jq 'length' 2>/dev/null) || violations_count=0

# Active alert policies
policies_raw=$(nr_get "${NR_API}/v2/alerts_policies.json") || policies_raw="{}"
alert_policies_active=$(echo "${policies_raw}" | jq '(.policies // []) | length' 2>/dev/null) || alert_policies_active=0

# SLO compliance via NRQL
slo_query="{ actor { account(id: ${OTTO_NEWRELIC_ACCOUNT_ID}) { nrql(query: \\\"SELECT count(*) FROM ServiceLevel WHERE status = 'compliant' OR status = 'non-compliant' FACET name LIMIT 20\\\") { results } } } }"
slo_raw=$(nr_gql "${slo_query}") || slo_raw="{}"
slo_compliance=$(echo "${slo_raw}" | jq '[(.data.actor.account.nrql.results // [])[] | {
    name: (.name // "unknown"),
    count: (.count // 0)
}]' 2>/dev/null) || slo_compliance="[]"

jq -n \
    --argjson violations "${violations}" \
    --argjson violations_count "${violations_count}" \
    --argjson alert_policies_active "${alert_policies_active}" \
    --argjson slo_compliance "${slo_compliance}" \
    '{
        violations: $violations,
        violations_count: $violations_count,
        alert_policies_active: $alert_policies_active,
        slo_compliance: $slo_compliance
    }'
