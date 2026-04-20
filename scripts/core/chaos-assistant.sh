#!/usr/bin/env bash
# OTTO - Chaos Engineering Assistant
# Safely run chaos experiments to validate system resilience.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CHAOS_ASSISTANT_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CHAOS_ASSISTANT_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/permissions.sh"

CHAOS_STATE_DIR="${OTTO_HOME}/state/chaos"

# --- Internal helpers ---

_chaos_ensure_state_dir() {
    mkdir -p "${CHAOS_STATE_DIR}"
}

_chaos_generate_id() {
    date +%Y%m%d-%H%M%S-$$
}

_chaos_record() {
    local experiment_id="$1" experiment="$2" target="$3" namespace="$4" duration="$5" status="$6"
    _chaos_ensure_state_dir
    jq -n --arg id "${experiment_id}" --arg exp "${experiment}" --arg tgt "${target}" \
        --arg ns "${namespace}" --arg dur "${duration}" --arg st "${status}" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{id: $id, experiment: $exp, target: $tgt, namespace: $ns, duration: $dur, status: $st, timestamp: $ts}' \
        > "${CHAOS_STATE_DIR}/${experiment_id}.json"
}

# --- Public API ---

# List available chaos experiments with descriptions.
# Usage: chaos_list_experiments
chaos_list_experiments() {
    jq -n '[
        {"name": "pod-kill", "description": "Kill a random pod matching a label selector", "risk": "low"},
        {"name": "network-delay", "description": "Inject network latency on a service (requires tc)", "risk": "medium"},
        {"name": "cpu-stress", "description": "Stress CPU on a target pod", "risk": "medium"},
        {"name": "disk-fill", "description": "Fill disk on a target pod to test pressure handling", "risk": "high"},
        {"name": "node-drain", "description": "Drain a Kubernetes node to test pod rescheduling", "risk": "high"}
    ]'
}

# Execute a chaos experiment with safety checks.
# All experiments require permission_enforce with "suggest" level minimum.
# Safety: never run in production unless explicitly configured.
# Usage: chaos_run <experiment> <target> <namespace> <duration_seconds>
chaos_run() {
    local experiment="$1"
    local target="$2"
    local namespace="${3:-default}"
    local duration="${4:-60}"

    # Permission check - require at least "suggest" level
    if ! permission_check "chaos" "run" "suggest" 2>/dev/null; then
        log_error "Chaos experiments require at least 'suggest' permission level"
        return 1
    fi

    # Safety: refuse production unless explicitly configured
    local allow_prod
    allow_prod=$(yq eval '.chaos.allow_production // "false"' "${OTTO_HOME}/config.yaml" 2>/dev/null) || allow_prod="false"
    if [[ "${namespace}" == "production" || "${namespace}" == "prod" ]] && [[ "${allow_prod}" != "true" ]]; then
        log_error "Chaos experiments are not allowed in production namespace. Set chaos.allow_production: true in config to override."
        return 1
    fi

    # Validate steady state before experiment
    log_info "Validating steady state before chaos experiment..."
    if ! chaos_validate_steady_state "${namespace}"; then
        log_error "System is not in steady state - aborting chaos experiment"
        return 1
    fi

    local experiment_id
    experiment_id=$(_chaos_generate_id)
    log_info "Starting chaos experiment ${experiment_id}: ${experiment} on ${target} in ${namespace} for ${duration}s"

    local result=1
    case "${experiment}" in
        pod-kill)      chaos_pod_kill "${namespace}" "${target}"; result=$? ;;
        network-delay) chaos_network_delay "${namespace}" "${target}" "${duration}"; result=$? ;;
        cpu-stress)    chaos_cpu_stress "${namespace}" "${target}" "1" "${duration}"; result=$? ;;
        disk-fill)     log_warn "disk-fill requires manual setup"; result=1 ;;
        node-drain)    log_warn "node-drain requires manual setup"; result=1 ;;
        *)             log_error "Unknown experiment: ${experiment}"; return 1 ;;
    esac

    local status="completed"
    [[ ${result} -ne 0 ]] && status="failed"

    _chaos_record "${experiment_id}" "${experiment}" "${target}" "${namespace}" "${duration}" "${status}"

    # Validate steady state after experiment
    log_info "Waiting for system to stabilize..."
    sleep 10
    if chaos_validate_steady_state "${namespace}"; then
        log_info "System recovered to steady state after chaos experiment"
    else
        log_warn "System has NOT recovered to steady state after chaos experiment"
        status="recovery_failed"
        _chaos_record "${experiment_id}" "${experiment}" "${target}" "${namespace}" "${duration}" "${status}"
    fi

    chaos_report "${experiment_id}"
}

# Kill a random pod matching a label selector.
# Usage: chaos_pod_kill <namespace> <label_selector>
chaos_pod_kill() {
    local namespace="$1"
    local label_selector="$2"

    local pods
    pods=$(kubectl get pods -n "${namespace}" -l "${label_selector}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null) || {
        log_error "Failed to list pods with selector ${label_selector} in ${namespace}"
        return 1
    }

    if [[ -z "${pods}" ]]; then
        log_error "No pods found matching selector ${label_selector} in ${namespace}"
        return 1
    fi

    # Pick a random pod
    local pod_array
    read -ra pod_array <<< "${pods}"
    local target_pod="${pod_array[RANDOM % ${#pod_array[@]}]}"

    log_info "Killing pod: ${target_pod} in namespace ${namespace}"
    kubectl delete pod "${target_pod}" -n "${namespace}" --grace-period=0 --force 2>/dev/null || {
        log_error "Failed to kill pod ${target_pod}"
        return 1
    }

    log_info "Pod ${target_pod} killed successfully"
}

# Inject network delay on a service (requires tc inside the pod).
# Usage: chaos_network_delay <namespace> <service> <delay_ms>
chaos_network_delay() {
    local namespace="$1"
    local service="$2"
    local delay_ms="${3:-200}"

    local pod
    pod=$(kubectl get pods -n "${namespace}" -l "app=${service}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || {
        log_error "No pod found for service ${service}"
        return 1
    }

    log_info "Injecting ${delay_ms}ms network delay on pod ${pod}"
    kubectl exec -n "${namespace}" "${pod}" -- tc qdisc add dev eth0 root netem delay "${delay_ms}ms" 2>/dev/null || {
        log_warn "Failed to inject delay - tc may not be available in the container"
        return 1
    }

    log_info "Network delay injected. Remove with: kubectl exec -n ${namespace} ${pod} -- tc qdisc del dev eth0 root"
}

# Stress CPU on a target pod.
# Usage: chaos_cpu_stress <namespace> <pod> <cores> <duration_seconds>
chaos_cpu_stress() {
    local namespace="$1"
    local pod="$2"
    local cores="${3:-1}"
    local duration="${4:-60}"

    log_info "Stressing ${cores} CPU core(s) on pod ${pod} for ${duration}s"
    kubectl exec -n "${namespace}" "${pod}" -- timeout "${duration}" sh -c \
        "for i in \$(seq 1 ${cores}); do yes > /dev/null & done; sleep ${duration}; kill 0" 2>/dev/null &

    log_info "CPU stress started in background for ${duration}s"
}

# Validate that the system is in a healthy steady state.
# Usage: chaos_validate_steady_state <namespace>
chaos_validate_steady_state() {
    local namespace="$1"
    local healthy=true

    # Check that all pods are Running or Succeeded
    local unhealthy_pods
    unhealthy_pods=$(kubectl get pods -n "${namespace}" --no-headers 2>/dev/null \
        | grep -cvE "Running|Completed|Succeeded" || true)

    if [[ "${unhealthy_pods}" -gt 0 ]]; then
        log_warn "${unhealthy_pods} unhealthy pod(s) in namespace ${namespace}"
        healthy=false
    fi

    # Check that all deployments have desired replicas
    local unavailable
    unavailable=$(kubectl get deployments -n "${namespace}" -o json 2>/dev/null \
        | jq '[.items[] | select(.status.unavailableReplicas > 0)] | length') || unavailable=0

    if [[ "${unavailable}" -gt 0 ]]; then
        log_warn "${unavailable} deployment(s) with unavailable replicas in ${namespace}"
        healthy=false
    fi

    [[ "${healthy}" == "true" ]]
}

# Generate a report for a chaos experiment.
# Usage: chaos_report <experiment_id>
chaos_report() {
    local experiment_id="$1"
    local report_file="${CHAOS_STATE_DIR}/${experiment_id}.json"

    if [[ ! -f "${report_file}" ]]; then
        log_error "No record found for experiment ${experiment_id}"
        return 1
    fi

    cat "${report_file}" | jq '
        . + {
            report: {
                summary: ("Chaos experiment \(.experiment) on \(.target) in \(.namespace): \(.status)"),
                recommendation: (
                    if .status == "recovery_failed" then
                        "System did not recover. Investigate resilience of the target service."
                    elif .status == "failed" then
                        "Experiment failed to execute. Check prerequisites and permissions."
                    else
                        "System recovered successfully. Resilience validated."
                    end
                )
            }
        }
    '
}
