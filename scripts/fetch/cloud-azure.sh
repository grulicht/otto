#!/usr/bin/env bash
# OTTO - Fetch Azure subscription overview
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"aks_clusters":0,"vms":0,"app_services":0,"sql_databases":0,"subscription":"unknown"}'

if ! command -v az &>/dev/null; then
    log_debug "az CLI not found, skipping Azure fetch"
    echo "${empty_result}"
    exit 0
fi

if ! az account show &>/dev/null 2>&1; then
    log_warn "Cannot authenticate to Azure"
    echo "${empty_result}"
    exit 0
fi

subscription=$(az account show --query 'name' -o tsv 2>/dev/null) || subscription="unknown"
aks_clusters=$(az aks list --query 'length(@)' -o tsv 2>/dev/null) || aks_clusters=0
vms=$(az vm list --query 'length(@)' -o tsv 2>/dev/null) || vms=0
app_services=$(az webapp list --query 'length(@)' -o tsv 2>/dev/null) || app_services=0
sql_databases=$(az sql db list --query 'length(@)' -o tsv 2>/dev/null) || sql_databases=0

jq -n \
    --argjson aks "${aks_clusters:-0}" \
    --argjson vms "${vms:-0}" \
    --argjson apps "${app_services:-0}" \
    --argjson sql "${sql_databases:-0}" \
    --arg sub "${subscription}" \
    '{
        aks_clusters: $aks,
        vms: $vms,
        app_services: $apps,
        sql_databases: $sql,
        subscription: $sub
    }'
