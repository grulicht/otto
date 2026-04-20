#!/usr/bin/env bash
# OTTO - Fetch Grafana Loki log aggregation stats
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"stream_count":0,"labels":[],"recent_log_volume":0,"ready":false}'

LOKI_URL="${OTTO_LOKI_URL:-http://localhost:3100}"
# shellcheck disable=SC2034
use_logcli=false

if command -v logcli &>/dev/null; then
    use_logcli=true
elif command -v curl &>/dev/null; then
    # shellcheck disable=SC2034
    use_logcli=false
else
    log_debug "Neither logcli nor curl found, skipping Loki fetch"
    echo "${empty_result}"
    exit 0
fi

# Test connectivity
if ! curl -s --max-time 10 "${LOKI_URL}/ready" 2>/dev/null | grep -qi "ready"; then
    log_debug "Cannot connect to Loki at ${LOKI_URL}"
    echo "${empty_result}"
    exit 0
fi

loki_get() {
    curl -s --max-time 15 "${LOKI_URL}${1}" 2>/dev/null
}

# Labels (proxy for stream diversity)
labels_raw=$(loki_get "/loki/api/v1/labels") || labels_raw="{}"
labels=$(echo "${labels_raw}" | jq '[(.data // [])[]]' 2>/dev/null) || labels="[]"

# Stream count via series endpoint
now_ns=$(date +%s)000000000
hour_ago_ns=$(( $(date +%s) - 3600 ))000000000
series_raw=$(curl -s --max-time 15 -X POST "${LOKI_URL}/loki/api/v1/series" \
    -d "start=${hour_ago_ns}" -d "end=${now_ns}" -d 'match[]={job=~".+"}' 2>/dev/null) || series_raw="{}"
stream_count=$(echo "${series_raw}" | jq '(.data // []) | length' 2>/dev/null) || stream_count=0

# Recent log volume (count of entries in last hour)
volume_raw=$(loki_get "/loki/api/v1/index/stats?start=${hour_ago_ns}&end=${now_ns}&query=%7Bjob%3D~%22.%2B%22%7D") || volume_raw="{}"
recent_log_volume=$(echo "${volume_raw}" | jq '.streams // 0' 2>/dev/null) || recent_log_volume=0

jq -n \
    --argjson stream_count "${stream_count}" \
    --argjson labels "${labels}" \
    --argjson recent_log_volume "${recent_log_volume}" \
    --argjson ready true \
    '{
        stream_count: $stream_count,
        labels: $labels,
        recent_log_volume: $recent_log_volume,
        ready: $ready
    }'
