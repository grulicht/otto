#!/usr/bin/env bash
# OTTO - Fetch DigitalOcean infrastructure status
# Outputs structured JSON to stdout
# Uses: doctl CLI or curl + DIGITALOCEAN_TOKEN
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"droplets":[],"kubernetes_clusters":[],"volumes":[],"databases":[]}'

DO_TOKEN="${DIGITALOCEAN_TOKEN:-}"
USE_CLI=false

if command -v doctl &>/dev/null && doctl account get &>/dev/null 2>&1; then
    USE_CLI=true
elif [[ -n "${DO_TOKEN}" ]] && command -v curl &>/dev/null && command -v jq &>/dev/null; then
    USE_CLI=false
else
    log_debug "Neither doctl CLI nor DIGITALOCEAN_TOKEN available, skipping DigitalOcean fetch"
    echo "${empty_result}"
    exit 0
fi

do_api_get() {
    curl -s --fail -H "Authorization: Bearer ${DO_TOKEN}" -H "Content-Type: application/json" "https://api.digitalocean.com/v2$1" 2>/dev/null
}

droplets="[]"
kubernetes_clusters="[]"
volumes="[]"
databases="[]"

if [[ "${USE_CLI}" == "true" ]]; then
    # Use doctl CLI
    if output=$(doctl compute droplet list --output json 2>/dev/null); then
        droplets=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            status: .status,
            region: .region.slug,
            size: .size_slug,
            vcpus: .vcpus,
            memory: .memory,
            disk: .disk,
            ip: (.networks.v4[]? | select(.type=="public") | .ip_address) // null,
            created_at: .created_at
        }]' 2>/dev/null) || droplets="[]"
    fi

    if output=$(doctl kubernetes cluster list --output json 2>/dev/null); then
        kubernetes_clusters=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            region: .region,
            version: .version,
            status: .status.state,
            node_count: ([.node_pools[]?.count] | add),
            created_at: .created_at
        }]' 2>/dev/null) || kubernetes_clusters="[]"
    fi

    if output=$(doctl compute volume list --output json 2>/dev/null); then
        volumes=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            size_gigabytes: .size_gigabytes,
            region: .region.slug,
            attached_to: (.droplet_ids // []),
            created_at: .created_at
        }]' 2>/dev/null) || volumes="[]"
    fi

    if output=$(doctl databases list --output json 2>/dev/null); then
        databases=$(echo "${output}" | jq '[.[]? | {
            id: .id,
            name: .name,
            engine: .engine,
            version: .version,
            status: .status,
            region: .region,
            size: .size,
            num_nodes: .num_nodes,
            created_at: .created_at
        }]' 2>/dev/null) || databases="[]"
    fi
else
    # Use REST API
    if response=$(do_api_get "/droplets?per_page=200"); then
        droplets=$(echo "${response}" | jq '[.droplets[]? | {
            id: .id,
            name: .name,
            status: .status,
            region: .region.slug,
            size: .size_slug,
            vcpus: .vcpus,
            memory: .memory,
            disk: .disk,
            ip: ([.networks.v4[]? | select(.type=="public")] | first | .ip_address) // null,
            created_at: .created_at
        }]' 2>/dev/null) || droplets="[]"
    fi

    if response=$(do_api_get "/kubernetes/clusters"); then
        kubernetes_clusters=$(echo "${response}" | jq '[.kubernetes_clusters[]? | {
            id: .id,
            name: .name,
            region: .region,
            version: .version,
            status: .status.state,
            node_count: ([.node_pools[]?.count] | add),
            created_at: .created_at
        }]' 2>/dev/null) || kubernetes_clusters="[]"
    fi

    if response=$(do_api_get "/volumes?per_page=200"); then
        volumes=$(echo "${response}" | jq '[.volumes[]? | {
            id: .id,
            name: .name,
            size_gigabytes: .size_gigabytes,
            region: .region.slug,
            attached_to: (.droplet_ids // []),
            created_at: .created_at
        }]' 2>/dev/null) || volumes="[]"
    fi

    if response=$(do_api_get "/databases"); then
        databases=$(echo "${response}" | jq '[.databases[]? | {
            id: .id,
            name: .name,
            engine: .engine,
            version: .version,
            status: .status,
            region: .region,
            size: .size,
            num_nodes: .num_nodes,
            created_at: .created_at
        }]' 2>/dev/null) || databases="[]"
    fi
fi

jq -n \
    --argjson droplets "${droplets}" \
    --argjson kubernetes_clusters "${kubernetes_clusters}" \
    --argjson volumes "${volumes}" \
    --argjson databases "${databases}" \
    '{
        droplets: $droplets,
        kubernetes_clusters: $kubernetes_clusters,
        volumes: $volumes,
        databases: $databases
    }'
