#!/usr/bin/env bash
# OTTO - Auto-Remediation Engine
# Configurable automatic fix engine for Night Watcher.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_AUTO_REMEDIATION_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_AUTO_REMEDIATION_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"

# Defaults
REMEDIATION_LOG="${OTTO_HOME}/state/night-watch/remediation.jsonl"
REMEDIATION_TIMEOUT="${REMEDIATION_TIMEOUT:-60}"
REMEDIATION_ALLOWED_ACTIONS="${REMEDIATION_ALLOWED_ACTIONS:-restart_crashed_pods,clear_disk_space,rotate_logs,restart_failed_service}"
REMEDIATION_FORBIDDEN_ACTIONS="${REMEDIATION_FORBIDDEN_ACTIONS:-}"

# --- Internal helpers ---

_remediation_ensure_log_dir() {
    mkdir -p "$(dirname "${REMEDIATION_LOG}")"
}

# --- Public API ---

# Log a remediation action to the night watch log.
# Usage: remediation_log <action> <target> <result>
remediation_log() {
    local action="$1"
    local target="$2"
    local result="$3"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    _remediation_ensure_log_dir

    printf '{"ts":"%s","action":"%s","target":"%s","result":"%s"}\n' \
        "${timestamp}" "${action}" "${target}" "${result}" >> "${REMEDIATION_LOG}"

    log_info "Remediation [${action}] on [${target}]: ${result}"
}

# Check if a remediation action is allowed.
# Usage: remediation_check_allowed <action_name>
# Returns 0 if allowed, 1 if forbidden.
remediation_check_allowed() {
    local action_name="$1"

    # Check forbidden list first
    local IFS=','
    for forbidden in ${REMEDIATION_FORBIDDEN_ACTIONS}; do
        if [[ "${forbidden}" == "${action_name}" ]]; then
            log_warn "Remediation action '${action_name}' is explicitly forbidden"
            return 1
        fi
    done

    # Check allowed list
    for allowed in ${REMEDIATION_ALLOWED_ACTIONS}; do
        if [[ "${allowed}" == "${action_name}" ]]; then
            return 0
        fi
    done

    log_warn "Remediation action '${action_name}' is not in the allowed list"
    return 1
}

# Execute a remediation action with full logging.
# Usage: remediation_execute <action_name> <target> <params>
remediation_execute() {
    local action_name="$1"
    local target="$2"
    local params="${3:-}"

    if ! remediation_check_allowed "${action_name}"; then
        remediation_log "${action_name}" "${target}" "DENIED"
        return 1
    fi

    log_info "Executing remediation: ${action_name} on ${target} (params: ${params})"
    remediation_log "${action_name}" "${target}" "STARTED"

    local result="SUCCESS"
    if ! timeout "${REMEDIATION_TIMEOUT}" bash -c "remediation_${action_name} ${target} ${params}" 2>&1; then
        result="FAILED"
    fi

    remediation_log "${action_name}" "${target}" "${result}"
    return "$([ "${result}" = "SUCCESS" ] && echo 0 || echo 1)"
}

# Find CrashLoopBackOff pods and restart them.
# Usage: remediation_restart_crashed_pods
remediation_restart_crashed_pods() {
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found - cannot restart crashed pods"
        return 1
    fi

    if ! remediation_check_allowed "restart_crashed_pods"; then
        return 1
    fi

    local pods
    pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running \
        -o json 2>/dev/null | \
        jq -r '.items[] |
            select(.status.containerStatuses[]? .state.waiting.reason == "CrashLoopBackOff") |
            "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || true)

    if [[ -z "${pods}" ]]; then
        log_info "No CrashLoopBackOff pods found"
        remediation_log "restart_crashed_pods" "cluster" "NO_ACTION_NEEDED"
        return 0
    fi

    local count=0
    while IFS= read -r pod_ref; do
        local ns="${pod_ref%%/*}"
        local pod="${pod_ref#*/}"
        log_info "Restarting CrashLoopBackOff pod: ${ns}/${pod}"
        remediation_log "restart_crashed_pods" "${ns}/${pod}" "STARTED"

        if timeout "${REMEDIATION_TIMEOUT}" kubectl delete pod "${pod}" -n "${ns}" --grace-period=30 2>&1; then
            # Verify the new pod is coming up
            sleep 5
            local phase
            phase=$(kubectl get pod -n "${ns}" -l "$(kubectl get pod "${pod}" -n "${ns}" -o jsonpath='{.metadata.labels}' 2>/dev/null | jq -r 'to_entries | map("\(.key)=\(.value)") | first' 2>/dev/null)" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
            remediation_log "restart_crashed_pods" "${ns}/${pod}" "SUCCESS (new pod phase: ${phase})"
            ((count++))
        else
            remediation_log "restart_crashed_pods" "${ns}/${pod}" "FAILED"
        fi
    done <<< "${pods}"

    log_info "Restarted ${count} CrashLoopBackOff pod(s)"
}

# Clean temp files, old logs, docker prune if disk >90%.
# Usage: remediation_clear_disk_space
remediation_clear_disk_space() {
    if ! remediation_check_allowed "clear_disk_space"; then
        return 1
    fi

    local usage
    usage=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %')

    if [[ "${usage}" -lt 90 ]]; then
        log_info "Disk usage at ${usage}% - below 90% threshold, no action needed"
        remediation_log "clear_disk_space" "/" "NO_ACTION_NEEDED (${usage}%)"
        return 0
    fi

    log_warn "Disk usage at ${usage}% - cleaning up"
    remediation_log "clear_disk_space" "/" "STARTED (${usage}%)"

    # Clean temp files older than 7 days
    find /tmp -type f -mtime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -mtime +7 -delete 2>/dev/null || true

    # Clean old journal logs (older than 3 days)
    if command -v journalctl &>/dev/null; then
        journalctl --vacuum-time=3d 2>/dev/null || true
    fi

    # Docker prune if available
    if command -v docker &>/dev/null; then
        docker system prune -f --volumes 2>/dev/null || true
    fi

    local new_usage
    new_usage=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
    remediation_log "clear_disk_space" "/" "SUCCESS (${usage}% -> ${new_usage}%)"
    log_info "Disk usage reduced from ${usage}% to ${new_usage}%"
}

# Truncate large log files and run logrotate.
# Usage: remediation_rotate_logs
remediation_rotate_logs() {
    if ! remediation_check_allowed "rotate_logs"; then
        return 1
    fi

    remediation_log "rotate_logs" "system" "STARTED"

    # Truncate log files larger than 500MB
    local truncated=0
    while IFS= read -r logfile; do
        local size_mb
        size_mb=$(du -m "${logfile}" 2>/dev/null | awk '{print $1}')
        if [[ "${size_mb}" -gt 500 ]]; then
            log_warn "Truncating large log file: ${logfile} (${size_mb}MB)"
            : > "${logfile}"
            ((truncated++))
        fi
    done < <(find /var/log -type f -name "*.log" 2>/dev/null || true)

    # Run logrotate if available
    if command -v logrotate &>/dev/null && [[ -f /etc/logrotate.conf ]]; then
        logrotate -f /etc/logrotate.conf 2>/dev/null || true
    fi

    remediation_log "rotate_logs" "system" "SUCCESS (truncated ${truncated} files)"
    log_info "Log rotation complete - truncated ${truncated} large file(s)"
}

# Restart a failed systemd service.
# Usage: remediation_restart_failed_service <service_name>
remediation_restart_failed_service() {
    local service_name="${1:-}"

    if [[ -z "${service_name}" ]]; then
        log_error "No service name provided"
        return 1
    fi

    if ! remediation_check_allowed "restart_failed_service"; then
        return 1
    fi

    if ! command -v systemctl &>/dev/null; then
        log_error "systemctl not found - cannot restart service"
        return 1
    fi

    local status
    status=$(systemctl is-active "${service_name}" 2>/dev/null || echo "unknown")

    if [[ "${status}" == "active" ]]; then
        log_info "Service ${service_name} is already active"
        remediation_log "restart_failed_service" "${service_name}" "NO_ACTION_NEEDED"
        return 0
    fi

    log_warn "Service ${service_name} is '${status}' - restarting"
    remediation_log "restart_failed_service" "${service_name}" "STARTED"

    if timeout "${REMEDIATION_TIMEOUT}" systemctl restart "${service_name}" 2>&1; then
        sleep 3
        local new_status
        new_status=$(systemctl is-active "${service_name}" 2>/dev/null || echo "unknown")
        if [[ "${new_status}" == "active" ]]; then
            remediation_log "restart_failed_service" "${service_name}" "SUCCESS"
            log_info "Service ${service_name} restarted successfully"
        else
            remediation_log "restart_failed_service" "${service_name}" "FAILED (status: ${new_status})"
            log_error "Service ${service_name} restart failed - status: ${new_status}"
            return 1
        fi
    else
        remediation_log "restart_failed_service" "${service_name}" "FAILED (timeout)"
        log_error "Service ${service_name} restart timed out"
        return 1
    fi
}

# Scale up a deployment if under pressure.
# Usage: remediation_scale_up <deployment> <namespace>
remediation_scale_up() {
    local deployment="${1:-}"
    local namespace="${2:-default}"

    if [[ -z "${deployment}" ]]; then
        log_error "No deployment name provided"
        return 1
    fi

    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found - cannot scale deployment"
        return 1
    fi

    if ! remediation_check_allowed "scale_up"; then
        return 1
    fi

    remediation_log "scale_up" "${namespace}/${deployment}" "STARTED"

    local current_replicas
    current_replicas=$(kubectl get deployment "${deployment}" -n "${namespace}" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    local new_replicas=$(( current_replicas + 1 ))
    log_info "Scaling ${namespace}/${deployment} from ${current_replicas} to ${new_replicas}"

    if timeout "${REMEDIATION_TIMEOUT}" kubectl scale deployment "${deployment}" \
        -n "${namespace}" --replicas="${new_replicas}" 2>&1; then
        sleep 10
        local ready
        ready=$(kubectl get deployment "${deployment}" -n "${namespace}" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        remediation_log "scale_up" "${namespace}/${deployment}" "SUCCESS (${current_replicas}->${new_replicas}, ready: ${ready})"
        log_info "Scaled ${namespace}/${deployment}: ready ${ready}/${new_replicas}"
    else
        remediation_log "scale_up" "${namespace}/${deployment}" "FAILED"
        log_error "Failed to scale ${namespace}/${deployment}"
        return 1
    fi
}
