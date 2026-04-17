#!/usr/bin/env bash
# OTTO - Check backup status across available backup tools
# Outputs structured JSON to stdout
# Supports: restic, borg, velero (reports on whichever are available)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

# Track whether any backup tool was found
any_tool_found=false

# --- Restic ---
restic_json="null"
if command -v restic &>/dev/null; then
    any_tool_found=true
    log_debug "Checking restic backup status"

    restic_last=""
    restic_count=0

    # RESTIC_REPOSITORY and RESTIC_PASSWORD_FILE / RESTIC_PASSWORD should be set
    if [[ -n "${RESTIC_REPOSITORY:-}" ]]; then
        # Get snapshot list
        if snapshots=$(restic snapshots --json --latest 1 2>/dev/null); then
            restic_last=$(echo "${snapshots}" | jq -r '.[0].time // ""' 2>/dev/null) || restic_last=""
        fi

        if all_snapshots=$(restic snapshots --json 2>/dev/null); then
            restic_count=$(echo "${all_snapshots}" | jq 'length' 2>/dev/null) || restic_count=0
        fi

        restic_json=$(jq -n \
            --arg last "${restic_last}" \
            --argjson count "${restic_count}" \
            '{ last_backup: $last, snapshots_count: $count }')
    else
        log_debug "RESTIC_REPOSITORY not set, skipping restic check"
        restic_json=$(jq -n '{ last_backup: "", snapshots_count: 0, note: "RESTIC_REPOSITORY not set" }')
    fi
else
    log_debug "restic not found"
fi

# --- Borg ---
borg_json="null"
if command -v borg &>/dev/null; then
    any_tool_found=true
    log_debug "Checking borg backup status"

    borg_last=""
    borg_count=0

    # BORG_REPO should be set
    if [[ -n "${BORG_REPO:-}" ]]; then
        if borg_list=$(borg list --json 2>/dev/null); then
            borg_count=$(echo "${borg_list}" | jq '.archives | length' 2>/dev/null) || borg_count=0
            borg_last=$(echo "${borg_list}" | jq -r '.archives[-1].start // ""' 2>/dev/null) || borg_last=""
        fi

        borg_json=$(jq -n \
            --arg last "${borg_last}" \
            --argjson count "${borg_count}" \
            '{ last_backup: $last, snapshots_count: $count }')
    else
        log_debug "BORG_REPO not set, skipping borg check"
        borg_json=$(jq -n '{ last_backup: "", snapshots_count: 0, note: "BORG_REPO not set" }')
    fi
else
    log_debug "borg not found"
fi

# --- Velero ---
velero_json="null"
if command -v velero &>/dev/null; then
    any_tool_found=true
    log_debug "Checking velero backup status"

    velero_last=""
    velero_count=0

    if velero_output=$(velero backup get -o json 2>/dev/null); then
        velero_count=$(echo "${velero_output}" | jq '.items | length' 2>/dev/null) || velero_count=0
        velero_last=$(echo "${velero_output}" | jq -r '
            [.items[] | select(.status.phase == "Completed")] |
            sort_by(.status.completionTimestamp) |
            last |
            .status.completionTimestamp // ""
        ' 2>/dev/null) || velero_last=""
    fi

    velero_json=$(jq -n \
        --arg last "${velero_last}" \
        --argjson count "${velero_count}" \
        '{ last_backup: $last, snapshots_count: $count }')
else
    log_debug "velero not found"
fi

# If no backup tools found at all, exit gracefully
if [[ "${any_tool_found}" == "false" ]]; then
    log_debug "No backup tools found (restic, borg, velero), skipping backup status"
    echo '{"restic":null,"borg":null,"velero":null}'
    exit 0
fi

# Assemble final JSON
jq -n \
    --argjson restic "${restic_json}" \
    --argjson borg "${borg_json}" \
    --argjson velero "${velero_json}" \
    '{
        restic: $restic,
        borg: $borg,
        velero: $velero
    }'
