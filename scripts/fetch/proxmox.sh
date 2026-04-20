#!/usr/bin/env bash
# OTTO - Fetch Proxmox VE cluster status
# Outputs structured JSON to stdout
# Uses: curl + OTTO_PROXMOX_URL + OTTO_PROXMOX_TOKEN (Proxmox REST API)
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"nodes":[],"vms":[],"containers":[],"storage":[],"cluster_status":null}'

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    log_debug "curl or jq not found, skipping Proxmox fetch"
    echo "${empty_result}"
    exit 0
fi

PVE_URL="${OTTO_PROXMOX_URL:-}"
PVE_TOKEN="${OTTO_PROXMOX_TOKEN:-}"

if [[ -z "${PVE_URL}" || -z "${PVE_TOKEN}" ]]; then
    log_warn "OTTO_PROXMOX_URL or OTTO_PROXMOX_TOKEN not set"
    echo "${empty_result}"
    exit 0
fi

PVE_BASE="${PVE_URL%/}/api2/json"

pve_get() {
    curl -s --fail -k -H "Authorization: PVEAPIToken=${PVE_TOKEN}" "$1" 2>/dev/null
}

# Fetch nodes
nodes="[]"
if response=$(pve_get "${PVE_BASE}/nodes"); then
    nodes=$(echo "${response}" | jq '[.data[]? | {
        node: .node,
        status: .status,
        cpu: .cpu,
        maxcpu: .maxcpu,
        mem: .mem,
        maxmem: .maxmem,
        disk: .disk,
        maxdisk: .maxdisk,
        uptime: .uptime
    }]' 2>/dev/null) || nodes="[]"
fi

# Fetch VMs and containers from each node
vms="[]"
containers="[]"
node_names=$(echo "${nodes}" | jq -r '.[].node // empty' 2>/dev/null) || node_names=""

for node in ${node_names}; do
    # VMs (QEMU)
    if response=$(pve_get "${PVE_BASE}/nodes/${node}/qemu"); then
        node_vms=$(echo "${response}" | jq --arg node "${node}" '[.data[]? | {
            vmid: .vmid,
            name: .name,
            status: .status,
            node: $node,
            cpus: .cpus,
            maxmem: .maxmem,
            maxdisk: .maxdisk,
            uptime: .uptime,
            template: (.template // false)
        }]' 2>/dev/null) || node_vms="[]"
        vms=$(echo "${vms}" | jq --argjson new "${node_vms}" '. + $new' 2>/dev/null) || true
    fi

    # Containers (LXC)
    if response=$(pve_get "${PVE_BASE}/nodes/${node}/lxc"); then
        node_cts=$(echo "${response}" | jq --arg node "${node}" '[.data[]? | {
            vmid: .vmid,
            name: .name,
            status: .status,
            node: $node,
            cpus: .cpus,
            maxmem: .maxmem,
            maxdisk: .maxdisk,
            uptime: .uptime,
            template: (.template // false)
        }]' 2>/dev/null) || node_cts="[]"
        containers=$(echo "${containers}" | jq --argjson new "${node_cts}" '. + $new' 2>/dev/null) || true
    fi
done

# Fetch storage
storage="[]"
if response=$(pve_get "${PVE_BASE}/storage"); then
    storage=$(echo "${response}" | jq '[.data[]? | {
        storage: .storage,
        type: .type,
        content: .content,
        shared: (.shared // 0),
        enabled: (.disable // 0 | if . == 0 then true else false end)
    }]' 2>/dev/null) || storage="[]"
fi

# Fetch cluster status
cluster_status="null"
if response=$(pve_get "${PVE_BASE}/cluster/status"); then
    cluster_status=$(echo "${response}" | jq '{
        nodes: [.data[]? | select(.type == "node") | {name: .name, online: (.online // 0), local: (.local // 0)}],
        quorate: ([.data[]? | select(.type == "cluster")] | first | .quorate // null),
        cluster_name: ([.data[]? | select(.type == "cluster")] | first | .name // null)
    }' 2>/dev/null) || cluster_status="null"
fi

jq -n \
    --argjson nodes "${nodes}" \
    --argjson vms "${vms}" \
    --argjson containers "${containers}" \
    --argjson storage "${storage}" \
    --argjson cluster_status "${cluster_status}" \
    '{
        nodes: $nodes,
        vms: $vms,
        containers: $containers,
        storage: $storage,
        cluster_status: $cluster_status
    }'
