#!/usr/bin/env bash
# OTTO - Hetzner cloud summary (wrapper for hetzner.sh)
# Outputs structured JSON summary to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

FETCH_SCRIPT="${OTTO_DIR}/scripts/fetch/hetzner.sh"

if [[ ! -x "${FETCH_SCRIPT}" ]]; then
    log_warn "hetzner.sh not found or not executable"
    echo '{"provider":"hetzner","servers":0,"volumes":0,"networks":0,"floating_ips":0}'
    exit 0
fi

raw_data=$("${FETCH_SCRIPT}" 2>/dev/null) || {
    echo '{"provider":"hetzner","servers":0,"volumes":0,"networks":0,"floating_ips":0}'
    exit 0
}

if ! command -v jq &>/dev/null; then
    echo "${raw_data}"
    exit 0
fi

echo "${raw_data}" | jq '{
    provider: "hetzner",
    servers: (.servers | length),
    servers_running: ([.servers[]? | select(.status == "running")] | length),
    volumes: (.volumes | length),
    networks: (.networks | length),
    floating_ips: (.floating_ips | length),
    details: .
}'
