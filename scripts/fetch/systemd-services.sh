#!/usr/bin/env bash
# OTTO - Fetch systemd failed services
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"failed_units":[],"total_units":0,"running_units":0,"failed_count":0}'

if ! command -v systemctl &>/dev/null; then
    log_debug "systemctl not found, skipping systemd fetch"
    echo "${empty_result}"
    exit 0
fi

# Failed units
failed_units=$(systemctl list-units --state=failed --no-pager --no-legend --plain 2>/dev/null \
    | awk '{print $1}' \
    | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null) || failed_units="[]"

failed_count=$(echo "${failed_units}" | jq 'length' 2>/dev/null) || failed_count=0

# Total loaded units
total_units=$(systemctl list-units --no-pager --no-legend --plain 2>/dev/null | wc -l | tr -d ' ') || total_units=0

# Running units
running_units=$(systemctl list-units --state=running --no-pager --no-legend --plain 2>/dev/null | wc -l | tr -d ' ') || running_units=0

jq -n \
    --argjson failed "${failed_units}" \
    --argjson total "${total_units}" \
    --argjson running "${running_units}" \
    --argjson fcount "${failed_count}" \
    '{
        failed_units: $failed,
        total_units: $total,
        running_units: $running,
        failed_count: $fcount
    }'
