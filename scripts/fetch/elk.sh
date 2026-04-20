#!/usr/bin/env bash
# OTTO - Fetch Elasticsearch/ELK stack status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"cluster_health":{},"index_count":0,"unassigned_shards":0,"kibana_status":"unknown"}'

if ! command -v curl &>/dev/null; then
    log_debug "curl not found, skipping ELK fetch"
    echo "${empty_result}"
    exit 0
fi

ES_URL="${OTTO_ELASTICSEARCH_URL:-http://localhost:9200}"
ES_AUTH=""
if [[ -n "${OTTO_ELASTICSEARCH_USER:-}" && -n "${OTTO_ELASTICSEARCH_PASS:-}" ]]; then
    ES_AUTH="-u ${OTTO_ELASTICSEARCH_USER}:${OTTO_ELASTICSEARCH_PASS}"
fi

es_get() {
    # shellcheck disable=SC2086
    curl -s --max-time 15 ${ES_AUTH} "$1" 2>/dev/null
}

# Test connectivity
if ! es_get "${ES_URL}/_cluster/health" | jq -e '.cluster_name' &>/dev/null; then
    log_debug "Cannot connect to Elasticsearch at ${ES_URL}"
    echo "${empty_result}"
    exit 0
fi

# Cluster health
health_raw=$(es_get "${ES_URL}/_cluster/health") || health_raw="{}"
cluster_health=$(echo "${health_raw}" | jq '{
    cluster_name: .cluster_name,
    status: .status,
    number_of_nodes: .number_of_nodes,
    number_of_data_nodes: .number_of_data_nodes,
    active_primary_shards: .active_primary_shards,
    active_shards: .active_shards,
    relocating_shards: .relocating_shards,
    initializing_shards: .initializing_shards,
    unassigned_shards: .unassigned_shards,
    pending_tasks: .number_of_pending_tasks
}' 2>/dev/null) || cluster_health="{}"

unassigned_shards=$(echo "${health_raw}" | jq '.unassigned_shards // 0' 2>/dev/null) || unassigned_shards=0

# Index count
indices_raw=$(es_get "${ES_URL}/_cat/indices?format=json") || indices_raw="[]"
index_count=$(echo "${indices_raw}" | jq 'length' 2>/dev/null) || index_count=0

# Kibana status
KIBANA_URL="${OTTO_KIBANA_URL:-}"
kibana_status="unknown"
if [[ -n "${KIBANA_URL}" ]]; then
    kibana_raw=$(curl -s --max-time 10 "${KIBANA_URL}/api/status" 2>/dev/null) || kibana_raw="{}"
    kibana_status=$(echo "${kibana_raw}" | jq -r '.status.overall.state // "unknown"' 2>/dev/null) || kibana_status="unknown"
fi

jq -n \
    --argjson cluster_health "${cluster_health}" \
    --argjson index_count "${index_count}" \
    --argjson unassigned_shards "${unassigned_shards}" \
    --arg kibana_status "${kibana_status}" \
    '{
        cluster_health: $cluster_health,
        index_count: $index_count,
        unassigned_shards: $unassigned_shards,
        kibana_status: $kibana_status
    }'
