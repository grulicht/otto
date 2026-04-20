#!/usr/bin/env bash
# OTTO - DigitalOcean cloud summary (wrapper for digitalocean.sh)
# Outputs structured JSON summary to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

FETCH_SCRIPT="${OTTO_DIR}/scripts/fetch/digitalocean.sh"

if [[ ! -x "${FETCH_SCRIPT}" ]]; then
    log_warn "digitalocean.sh not found or not executable"
    echo '{"provider":"digitalocean","droplets":0,"kubernetes_clusters":0,"volumes":0,"databases":0}'
    exit 0
fi

raw_data=$("${FETCH_SCRIPT}" 2>/dev/null) || {
    echo '{"provider":"digitalocean","droplets":0,"kubernetes_clusters":0,"volumes":0,"databases":0}'
    exit 0
}

if ! command -v jq &>/dev/null; then
    echo "${raw_data}"
    exit 0
fi

echo "${raw_data}" | jq '{
    provider: "digitalocean",
    droplets: (.droplets | length),
    droplets_running: ([.droplets[]? | select(.status == "active")] | length),
    kubernetes_clusters: (.kubernetes_clusters | length),
    volumes: (.volumes | length),
    databases: (.databases | length),
    details: .
}'
