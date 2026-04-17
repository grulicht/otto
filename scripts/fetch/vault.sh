#!/usr/bin/env bash
# OTTO - Fetch HashiCorp Vault status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"sealed":true,"version":"unknown","cluster_name":"unknown","secrets_engines":0,"auth_methods":0}'

if ! command -v vault &>/dev/null; then
    log_debug "vault CLI not found, skipping Vault fetch"
    echo "${empty_result}"
    exit 0
fi

if [[ -z "${VAULT_ADDR:-}" ]]; then
    log_warn "VAULT_ADDR not set"
    echo "${empty_result}"
    exit 0
fi

# Get status
status_json=$(vault status -format=json 2>/dev/null) || {
    log_warn "Cannot connect to Vault"
    echo "${empty_result}"
    exit 0
}

sealed=$(echo "${status_json}" | jq -r '.sealed' 2>/dev/null) || sealed=true
version=$(echo "${status_json}" | jq -r '.version // "unknown"' 2>/dev/null) || version="unknown"
cluster_name=$(echo "${status_json}" | jq -r '.cluster_name // "unknown"' 2>/dev/null) || cluster_name="unknown"

secrets_engines=0
auth_methods=0
if [[ "${sealed}" == "false" ]]; then
    secrets_engines=$(vault secrets list -format=json 2>/dev/null | jq 'keys | length' 2>/dev/null) || secrets_engines=0
    auth_methods=$(vault auth list -format=json 2>/dev/null | jq 'keys | length' 2>/dev/null) || auth_methods=0
fi

jq -n \
    --argjson sealed "${sealed}" \
    --arg version "${version}" \
    --arg cluster "${cluster_name}" \
    --argjson engines "${secrets_engines}" \
    --argjson auth "${auth_methods}" \
    '{
        sealed: $sealed,
        version: $version,
        cluster_name: $cluster,
        secrets_engines: $engines,
        auth_methods: $auth
    }'
