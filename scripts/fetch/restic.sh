#!/usr/bin/env bash
# OTTO - Fetch Restic backup status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"repository":"unknown","snapshots_count":0,"last_snapshot":"unknown","last_snapshot_age_hours":0,"repository_size":"unknown"}'

if ! command -v restic &>/dev/null; then
    log_debug "restic not found, skipping Restic fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    log_warn "RESTIC_REPOSITORY not set"
    echo "${empty_result}"
    exit 0
fi

repository="${RESTIC_REPOSITORY}"

# Snapshots
snapshots_json=$(restic snapshots --json 2>/dev/null) || {
    log_warn "Cannot access restic repository"
    echo "${empty_result}"
    exit 0
}

snapshots_count=$(echo "${snapshots_json}" | jq 'length' 2>/dev/null) || snapshots_count=0
last_snapshot="unknown"
last_snapshot_age_hours=0

if [[ "${snapshots_count}" -gt 0 ]]; then
    last_snapshot=$(echo "${snapshots_json}" | jq -r 'sort_by(.time) | last | .time' 2>/dev/null) || last_snapshot="unknown"
    if [[ "${last_snapshot}" != "unknown" ]]; then
        last_epoch=$(date -d "${last_snapshot}" +%s 2>/dev/null) || last_epoch=0
        now_epoch=$(date +%s)
        if [[ "${last_epoch}" -gt 0 ]]; then
            last_snapshot_age_hours=$(( (now_epoch - last_epoch) / 3600 ))
        fi
    fi
fi

# Repository size
repository_size="unknown"
if stats_json=$(restic stats --json 2>/dev/null); then
    repository_size=$(echo "${stats_json}" | jq -r '.total_size // 0' 2>/dev/null | numfmt --to=iec 2>/dev/null) || repository_size="unknown"
fi

jq -n \
    --arg repo "${repository}" \
    --argjson count "${snapshots_count}" \
    --arg last "${last_snapshot}" \
    --argjson age "${last_snapshot_age_hours}" \
    --arg size "${repository_size}" \
    '{
        repository: $repo,
        snapshots_count: $count,
        last_snapshot: $last,
        last_snapshot_age_hours: $age,
        repository_size: $size
    }'
