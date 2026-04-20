#!/usr/bin/env bash
# OTTO - Fetch Kubernetes cluster status
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

# Graceful exit if kubectl is not installed
if ! command -v kubectl &>/dev/null; then
    log_debug "kubectl not found, skipping Kubernetes fetch"
    echo '{"nodes":[],"pods_not_ready":[],"deployments":[],"events_warning":[],"resource_usage":{}}'
    exit 0
fi

# Verify cluster connectivity
if ! kubectl cluster-info &>/dev/null; then
    log_warn "Cannot connect to Kubernetes cluster"
    echo '{"nodes":[],"pods_not_ready":[],"deployments":[],"events_warning":[],"resource_usage":{}}'
    exit 0
fi

# Default empty result for graceful degradation
# Used via: echo "${empty_result}" in error handlers below

# Fetch nodes
nodes=$(kubectl get nodes -o json 2>/dev/null | jq '[.items[] | {
    name: .metadata.name,
    status: (.status.conditions[] | select(.type=="Ready") | .status),
    roles: ([.metadata.labels | to_entries[] | select(.key | startswith("node-role.kubernetes.io/")) | .key | split("/")[1]] | join(",")),
    version: .status.nodeInfo.kubeletVersion
}]' 2>/dev/null) || nodes="[]"

# Fetch pods that are not ready
pods_not_ready=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq '[.items[] | select(
    .status.phase != "Running" and .status.phase != "Succeeded"
    or (.status.containerStatuses // [] | any(.ready == false))
) | {
    namespace: .metadata.namespace,
    name: .metadata.name,
    phase: .status.phase,
    restarts: ([.status.containerStatuses // [] | .[].restartCount] | add // 0),
    reason: (.status.containerStatuses // [] | .[0].state | to_entries[0].value.reason // null)
}] | .[0:50]' 2>/dev/null) || pods_not_ready="[]"

# Fetch deployments
deployments=$(kubectl get deployments --all-namespaces -o json 2>/dev/null | jq '[.items[] | {
    namespace: .metadata.namespace,
    name: .metadata.name,
    ready: "\(.status.readyReplicas // 0)/\(.spec.replicas // 0)",
    up_to_date: (.status.updatedReplicas // 0),
    available: (.status.availableReplicas // 0)
}]' 2>/dev/null) || deployments="[]"

# Fetch warning events (last hour)
events_warning=$(kubectl get events --all-namespaces --field-selector type=Warning \
    -o json 2>/dev/null | jq '[.items[] | {
    namespace: .metadata.namespace,
    reason: .reason,
    message: .message,
    object: "\(.involvedObject.kind)/\(.involvedObject.name)",
    count: (.count // 1),
    last_seen: .lastTimestamp
}] | sort_by(.last_seen) | reverse | .[0:20]' 2>/dev/null) || events_warning="[]"

# Fetch resource usage (requires metrics-server)
resource_usage="{}"
if kubectl top nodes &>/dev/null 2>&1; then
    cpu_alloc=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum += $3} END {printf "%.0f", sum}') || cpu_alloc="0"
    mem_alloc=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum += $5} END {printf "%.0f", sum}') || mem_alloc="0"
    resource_usage=$(jq -n \
        --argjson cpu "${cpu_alloc:-0}" \
        --argjson mem "${mem_alloc:-0}" \
        '{"cpu_percent": $cpu, "memory_percent": $mem}')
fi

# Assemble final JSON
jq -n \
    --argjson nodes "${nodes}" \
    --argjson pods_not_ready "${pods_not_ready}" \
    --argjson deployments "${deployments}" \
    --argjson events_warning "${events_warning}" \
    --argjson resource_usage "${resource_usage}" \
    '{
        nodes: $nodes,
        pods_not_ready: $pods_not_ready,
        deployments: $deployments,
        events_warning: $events_warning,
        resource_usage: $resource_usage
    }'
