#!/usr/bin/env bash
# OTTO - Multi-Cluster/Multi-Cloud Management
# Manage multiple Kubernetes clusters and cloud providers from a single pane.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_MULTI_CLUSTER_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_MULTI_CLUSTER_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"

# --- Public API ---

# List all configured Kubernetes contexts from kubeconfig.
# Usage: cluster_list
cluster_list() {
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found"
        return 1
    fi

    local contexts
    contexts=$(kubectl config get-contexts -o name 2>/dev/null) || {
        log_error "Failed to list Kubernetes contexts"
        return 1
    }

    local current
    current=$(kubectl config current-context 2>/dev/null) || current=""

    local result="[]"
    while IFS= read -r ctx; do
        [[ -z "${ctx}" ]] && continue
        local is_current="false"
        [[ "${ctx}" == "${current}" ]] && is_current="true"
        local cluster server
        cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.cluster}" 2>/dev/null) || cluster=""
        server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"${cluster}\")].cluster.server}" 2>/dev/null) || server=""
        result=$(echo "${result}" | jq --arg name "${ctx}" --arg server "${server}" --argjson current "${is_current}" \
            '. + [{"context": $name, "server": $server, "current": $current}]')
    done <<< "${contexts}"

    echo "${result}" | jq .
}

# Run kubernetes health check for each configured context and aggregate results.
# Usage: cluster_status_all
cluster_status_all() {
    local contexts
    contexts=$(kubectl config get-contexts -o name 2>/dev/null) || {
        log_error "Failed to list Kubernetes contexts"
        return 1
    }

    local results="[]"
    while IFS= read -r ctx; do
        [[ -z "${ctx}" ]] && continue
        log_info "Checking cluster: ${ctx}"
        local status="ok"
        local nodes=0 pods=0
        nodes=$(kubectl --context "${ctx}" get nodes --no-headers 2>/dev/null | wc -l) || { status="unreachable"; nodes=0; }
        pods=$(kubectl --context "${ctx}" get pods -A --no-headers 2>/dev/null | wc -l) || pods=0

        local not_ready
        not_ready=$(kubectl --context "${ctx}" get nodes --no-headers 2>/dev/null | grep -cv " Ready " || true)
        [[ "${not_ready}" -gt 0 ]] && status="degraded"

        results=$(echo "${results}" | jq --arg ctx "${ctx}" --arg status "${status}" \
            --argjson nodes "${nodes}" --argjson pods "${pods}" \
            '. + [{"context": $ctx, "status": $status, "nodes": $nodes, "pods": $pods}]')
    done <<< "${contexts}"

    echo "${results}" | jq .
}

# Compare two Kubernetes clusters (versions, node counts, deployments).
# Usage: cluster_compare <context1> <context2>
cluster_compare() {
    local ctx1="$1"
    local ctx2="$2"

    local info=""
    for ctx in "${ctx1}" "${ctx2}"; do
        local version nodes deployments
        version=$(kubectl --context "${ctx}" version --short 2>/dev/null | grep Server | awk '{print $3}') || version="unknown"
        nodes=$(kubectl --context "${ctx}" get nodes --no-headers 2>/dev/null | wc -l) || nodes=0
        deployments=$(kubectl --context "${ctx}" get deployments -A --no-headers 2>/dev/null | wc -l) || deployments=0
        info="${info}$(jq -n --arg ctx "${ctx}" --arg ver "${version}" \
            --argjson nodes "${nodes}" --argjson deps "${deployments}" \
            '{"context": $ctx, "server_version": $ver, "nodes": $nodes, "deployments": $deps}') "
    done

    echo "${info}" | jq -s '{cluster_1: .[0], cluster_2: .[1], differences: {
        version_match: (.[0].server_version == .[1].server_version),
        node_diff: (.[0].nodes - .[1].nodes),
        deployment_diff: (.[0].deployments - .[1].deployments)
    }}'
}

# Deploy to multiple clusters sequentially with health checks between each.
# Usage: cluster_deploy_multi <target> <version> <contexts_list_comma_separated>
cluster_deploy_multi() {
    local target="$1"
    local version="$2"
    local contexts_csv="$3"

    IFS=',' read -ra ctx_list <<< "${contexts_csv}"
    local results="[]"

    for ctx in "${ctx_list[@]}"; do
        ctx=$(echo "${ctx}" | xargs)  # trim whitespace
        log_info "Deploying ${target}:${version} to cluster: ${ctx}"

        local deploy_status="success"
        if ! kubectl --context "${ctx}" set image "deployment/${target}" "${target}=${target}:${version}" 2>/dev/null; then
            log_error "Failed to update image on ${ctx}"
            deploy_status="failed"
        fi

        if [[ "${deploy_status}" == "success" ]]; then
            log_info "Waiting for rollout on ${ctx}..."
            if ! kubectl --context "${ctx}" rollout status "deployment/${target}" --timeout=300s 2>/dev/null; then
                log_error "Rollout failed on ${ctx}, stopping multi-deploy"
                deploy_status="rollout_failed"
            fi
        fi

        results=$(echo "${results}" | jq --arg ctx "${ctx}" --arg status "${deploy_status}" \
            '. + [{"context": $ctx, "status": $status}]')

        if [[ "${deploy_status}" != "success" ]]; then
            log_error "Aborting remaining deployments due to failure on ${ctx}"
            break
        fi

        log_info "Health check passed on ${ctx}"
    done

    echo "${results}" | jq .
}

# Guide failover process from one cluster to another for a given service.
# Usage: cluster_failover <from_context> <to_context> <service>
cluster_failover() {
    local from_ctx="$1"
    local to_ctx="$2"
    local service="$3"

    log_info "Starting failover of ${service}: ${from_ctx} -> ${to_ctx}"

    # Verify service exists on target
    if ! kubectl --context "${to_ctx}" get "deployment/${service}" &>/dev/null; then
        log_error "Service ${service} not found on target cluster ${to_ctx}"
        return 1
    fi

    # Scale up on target
    local current_replicas
    current_replicas=$(kubectl --context "${from_ctx}" get "deployment/${service}" -o jsonpath='{.spec.replicas}' 2>/dev/null) || current_replicas=1
    log_info "Scaling ${service} on ${to_ctx} to ${current_replicas} replicas"
    kubectl --context "${to_ctx}" scale "deployment/${service}" --replicas="${current_replicas}" 2>/dev/null || {
        log_error "Failed to scale up on target"
        return 1
    }

    # Wait for target to be ready
    log_info "Waiting for ${service} to be ready on ${to_ctx}..."
    kubectl --context "${to_ctx}" rollout status "deployment/${service}" --timeout=300s 2>/dev/null || {
        log_error "Target deployment not ready, aborting failover"
        return 1
    }

    # Scale down on source
    log_info "Scaling down ${service} on ${from_ctx}"
    kubectl --context "${from_ctx}" scale "deployment/${service}" --replicas=0 2>/dev/null || {
        log_warn "Failed to scale down source - service may be running on both clusters"
    }

    jq -n --arg service "${service}" --arg from "${from_ctx}" --arg to "${to_ctx}" \
        --argjson replicas "${current_replicas}" \
        '{"status": "complete", "service": $service, "from": $from, "to": $to, "replicas": $replicas}'
}

# Run all cloud-* fetch scripts and show a combined multi-cloud view.
# Usage: multicloud_status
multicloud_status() {
    local fetch_dir="${OTTO_DIR}/scripts/fetch"
    local results="{}"

    if [[ ! -d "${fetch_dir}" ]]; then
        log_warn "No fetch scripts directory found at ${fetch_dir}"
        echo '{"providers": {}}'
        return 0
    fi

    for cloud_script in "${fetch_dir}"/cloud-*.sh; do
        [[ -f "${cloud_script}" ]] || continue
        local provider
        provider=$(basename "${cloud_script}" .sh | sed 's/^cloud-//')
        log_info "Fetching status for provider: ${provider}"
        local output
        output=$("${cloud_script}" 2>/dev/null) || output='{"status": "error"}'
        results=$(echo "${results}" | jq --arg p "${provider}" --argjson d "${output}" '.providers[$p] = $d')
    done

    echo "${results}" | jq .
}

# Compare costs across cloud providers.
# Usage: multicloud_cost_comparison
multicloud_cost_comparison() {
    local state_dir="${OTTO_HOME}/state"
    local results="[]"

    for cost_file in "${state_dir}"/cost-*.json; do
        [[ -f "${cost_file}" ]] || continue
        local provider
        provider=$(basename "${cost_file}" .json | sed 's/^cost-//')
        local cost_data
        cost_data=$(cat "${cost_file}" 2>/dev/null) || cost_data='{}'
        results=$(echo "${results}" | jq --arg p "${provider}" --argjson d "${cost_data}" \
            '. + [{"provider": $p, "data": $d}]')
    done

    if [[ "$(echo "${results}" | jq 'length')" -eq 0 ]]; then
        log_warn "No cost data found. Run cost-analyzer first."
        echo '{"providers": [], "note": "No cost data available"}'
        return 0
    fi

    echo "${results}" | jq '{
        providers: .,
        summary: {
            total_monthly: [.[].data.monthly_total // 0] | add,
            cheapest: (sort_by(.data.monthly_total // 999999) | first | .provider),
            most_expensive: (sort_by(.data.monthly_total // 0) | last | .provider)
        }
    }'
}
