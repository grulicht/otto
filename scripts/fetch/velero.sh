#!/usr/bin/env bash
# OTTO - Fetch Velero backup and restore status
# Outputs structured JSON to stdout
# Uses: velero CLI
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"backups":[],"schedules":[],"restores":[]}'

if ! command -v velero &>/dev/null; then
    log_debug "velero CLI not found, skipping Velero fetch"
    echo "${empty_result}"
    exit 0
fi

if ! command -v jq &>/dev/null; then
    log_debug "jq not found, skipping Velero fetch"
    echo "${empty_result}"
    exit 0
fi

# Fetch backups
backups="[]"
if output=$(velero backup get -o json 2>/dev/null); then
    backups=$(echo "${output}" | jq '[.items[]? | {
        name: .metadata.name,
        status: .status.phase,
        errors: (.status.errors // 0),
        warnings: (.status.warnings // 0),
        started: .status.startTimestamp,
        completed: .status.completionTimestamp,
        expiration: .status.expiration,
        included_namespaces: (.spec.includedNamespaces // ["*"]),
        storage_location: .spec.storageLocation
    }]' 2>/dev/null) || backups="[]"
fi

# Fetch schedules
schedules="[]"
if output=$(velero schedule get -o json 2>/dev/null); then
    schedules=$(echo "${output}" | jq '[.items[]? | {
        name: .metadata.name,
        schedule: .spec.schedule,
        last_backup: .status.lastBackup,
        paused: (.spec.paused // false),
        included_namespaces: (.spec.template.includedNamespaces // ["*"]),
        storage_location: .spec.template.storageLocation
    }]' 2>/dev/null) || schedules="[]"
fi

# Fetch restores
restores="[]"
if output=$(velero restore get -o json 2>/dev/null); then
    restores=$(echo "${output}" | jq '[.items[]? | {
        name: .metadata.name,
        backup: .spec.backupName,
        status: .status.phase,
        errors: (.status.errors // 0),
        warnings: (.status.warnings // 0),
        started: .status.startTimestamp,
        completed: .status.completionTimestamp
    }]' 2>/dev/null) || restores="[]"
fi

jq -n \
    --argjson backups "${backups}" \
    --argjson schedules "${schedules}" \
    --argjson restores "${restores}" \
    '{
        backups: $backups,
        schedules: $schedules,
        restores: $restores
    }'
