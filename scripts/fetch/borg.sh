#!/usr/bin/env bash
# OTTO - Fetch BorgBackup repository info
# Outputs structured JSON to stdout
# Uses: borg CLI + BORG_REPO
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"repository":"unknown","archive_count":0,"last_archive":"unknown","last_archive_age_hours":0,"repository_size":"unknown"}'

if ! command -v borg &>/dev/null; then
    log_debug "borg not found, skipping BorgBackup fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${BORG_REPO:-}" ]]; then
    log_warn "BORG_REPO not set"
    echo "${empty_result}"
    exit 0
fi

repository="${BORG_REPO}"

# Get repo info
repo_info_json=$(borg info --json 2>/dev/null) || {
    log_warn "Cannot access borg repository"
    echo "${empty_result}"
    exit 0
}

# Archive count
archive_count=$(echo "${repo_info_json}" | jq '.archives | length' 2>/dev/null) || archive_count=0

# Last archive
last_archive="unknown"
last_archive_age_hours=0
if [[ "${archive_count}" -gt 0 ]]; then
    last_archive=$(echo "${repo_info_json}" | jq -r '.archives | sort_by(.start) | last | .start' 2>/dev/null) || last_archive="unknown"
    if [[ "${last_archive}" != "unknown" && "${last_archive}" != "null" ]]; then
        last_epoch=$(date -d "${last_archive}" +%s 2>/dev/null) || last_epoch=0
        now_epoch=$(date +%s)
        if [[ "${last_epoch}" -gt 0 ]]; then
            last_archive_age_hours=$(( (now_epoch - last_epoch) / 3600 ))
        fi
    fi
fi

# Repository size
repository_size="unknown"
# shellcheck disable=SC2034
repo_size_bytes=$(echo "${repo_info_json}" | jq '.repository.location // empty' 2>/dev/null) || true
if stats_json=$(echo "${repo_info_json}" | jq '.cache.stats' 2>/dev/null); then
    unique_size=$(echo "${stats_json}" | jq '.unique_size // 0' 2>/dev/null) || unique_size=0
    if [[ "${unique_size}" -gt 0 ]]; then
        repository_size=$(numfmt --to=iec "${unique_size}" 2>/dev/null) || repository_size="${unique_size} bytes"
    fi
fi

jq -n \
    --arg repo "${repository}" \
    --argjson count "${archive_count}" \
    --arg last "${last_archive}" \
    --argjson age "${last_archive_age_hours}" \
    --arg size "${repository_size}" \
    '{
        repository: $repo,
        archive_count: $count,
        last_archive: $last,
        last_archive_age_hours: $age,
        repository_size: $size
    }'
