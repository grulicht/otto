#!/usr/bin/env bash
# OTTO - Service restart helper
# Supports: systemctl restart, docker restart, kubectl rollout restart
# Usage: restart-service.sh --service <name> [--host <host>] [--method systemctl|docker|kubectl] [--dry-run]
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/json-utils.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/core/permissions.sh"

SERVICE_NAME=""
HOST=""
METHOD=""
DRY_RUN=false
NAMESPACE=""
RESOURCE_TYPE="deployment"
ENVIRONMENT=""
SSH_USER=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Restart a service.

Options:
    --service <name>        Service name (required)
    --host <host>           Remote host (for systemctl via SSH; omit for local)
    --environment <env>     Environment name (optional, for permissions)
    --method <method>       Restart method: systemctl, docker, kubectl (auto-detected if omitted)
    --namespace <ns>        Kubernetes namespace (for kubectl method)
    --resource-type <type>  Resource type: deployment, statefulset, daemonset (default: deployment)
    --ssh-user <user>       SSH user for remote operations
    --dry-run               Preview changes without applying
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --service)       SERVICE_NAME="$2"; shift 2 ;;
            --host)          HOST="$2"; shift 2 ;;
            --environment)   ENVIRONMENT="$2"; shift 2 ;;
            --method)        METHOD="$2"; shift 2 ;;
            --namespace)     NAMESPACE="$2"; shift 2 ;;
            --resource-type) RESOURCE_TYPE="$2"; shift 2 ;;
            --ssh-user)      SSH_USER="$2"; shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${SERVICE_NAME}" ]]; then
        log_error "Missing required argument: --service"
        usage
        exit 1
    fi
}

detect_method() {
    if [[ -n "${METHOD}" ]]; then
        return
    fi

    if [[ -n "${NAMESPACE}" ]] && command -v kubectl &>/dev/null; then
        METHOD="kubectl"
    elif command -v docker &>/dev/null && docker ps --filter "name=${SERVICE_NAME}" --format '{{.Names}}' 2>/dev/null | grep -q .; then
        METHOD="docker"
    elif command -v systemctl &>/dev/null || [[ -n "${HOST}" ]]; then
        METHOD="systemctl"
    else
        log_error "Cannot detect restart method. Specify --method explicitly."
        exit 1
    fi

    log_info "Auto-detected restart method: ${METHOD}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg host "${HOST:-localhost}" \
        --arg method "${METHOD}" \
        --arg environment "${ENVIRONMENT:-}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            host: $host,
            method: $method,
            environment: $environment,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

run_remote_or_local() {
    if [[ -n "${HOST}" ]]; then
        local ssh_target="${HOST}"
        [[ -n "${SSH_USER}" ]] && ssh_target="${SSH_USER}@${HOST}"
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${ssh_target}" "$@"
    else
        "$@"
    fi
}

restart_systemctl() {
    local host_display="${HOST:-localhost}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        local status
        status=$(run_remote_or_local systemctl is-active "${SERVICE_NAME}" 2>/dev/null) || status="unknown"
        log_info "[DRY-RUN] Would restart '${SERVICE_NAME}' on ${host_display} (current: ${status})"
        output_result "restart" "${SERVICE_NAME}" "dry-run" "Would restart systemd service on ${host_display} (current: ${status})"
        return
    fi

    log_info "Restarting systemd service '${SERVICE_NAME}' on ${host_display}"
    local output
    output=$(run_remote_or_local sudo systemctl restart "${SERVICE_NAME}" 2>&1) || {
        output_result "restart" "${SERVICE_NAME}" "failed" "systemctl restart failed on ${host_display}: ${output}"
        exit 1
    }

    local status
    status=$(run_remote_or_local systemctl is-active "${SERVICE_NAME}" 2>/dev/null) || status="unknown"

    if [[ "${status}" == "active" ]]; then
        output_result "restart" "${SERVICE_NAME}" "success" "Service restarted on ${host_display}, status: ${status}"
    else
        output_result "restart" "${SERVICE_NAME}" "warning" "Service restarted but status is: ${status}"
    fi
}

restart_docker() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        local status
        status=$(docker inspect --format '{{.State.Status}}' "${SERVICE_NAME}" 2>/dev/null) || status="unknown"
        log_info "[DRY-RUN] Would restart Docker container '${SERVICE_NAME}' (current: ${status})"
        output_result "restart" "${SERVICE_NAME}" "dry-run" "Would restart Docker container (current: ${status})"
        return
    fi

    log_info "Restarting Docker container '${SERVICE_NAME}'"
    local output
    output=$(docker restart "${SERVICE_NAME}" 2>&1) || {
        output_result "restart" "${SERVICE_NAME}" "failed" "docker restart failed: ${output}"
        exit 1
    }

    local status
    status=$(docker inspect --format '{{.State.Status}}' "${SERVICE_NAME}" 2>/dev/null) || status="unknown"
    output_result "restart" "${SERVICE_NAME}" "success" "Docker container restarted, status: ${status}"
}

restart_kubectl() {
    local ns="${NAMESPACE:-default}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        local ready
        ready=$(kubectl -n "${ns}" get "${RESOURCE_TYPE}/${SERVICE_NAME}" -o json 2>/dev/null | \
            jq -r '"\(.status.readyReplicas // 0)/\(.status.replicas // 0)"' 2>/dev/null) || ready="unknown"
        log_info "[DRY-RUN] Would rollout restart ${RESOURCE_TYPE}/${SERVICE_NAME} in ${ns} (ready: ${ready})"
        output_result "restart" "${SERVICE_NAME}" "dry-run" "Would rollout restart in ${ns} (ready: ${ready})"
        return
    fi

    log_info "Restarting ${RESOURCE_TYPE}/${SERVICE_NAME} in namespace ${ns}"
    local output
    output=$(kubectl -n "${ns}" rollout restart "${RESOURCE_TYPE}/${SERVICE_NAME}" 2>&1) || {
        output_result "restart" "${SERVICE_NAME}" "failed" "kubectl rollout restart failed: ${output}"
        exit 1
    }
    kubectl -n "${ns}" rollout status "${RESOURCE_TYPE}/${SERVICE_NAME}" --timeout=300s 2>&1 || true
    output_result "restart" "${SERVICE_NAME}" "success" "Rollout restart completed: ${output}"
}

main() {
    parse_args "$@"
    detect_method

    local host_display="${HOST:-localhost}"
    local description="Restart service '${SERVICE_NAME}' on ${host_display} via ${METHOD}"

    if ! permission_enforce "service" "restart" "${ENVIRONMENT}" "${description}"; then
        output_result "restart" "${SERVICE_NAME}" "denied" "Permission denied for restarting ${SERVICE_NAME}"
        exit 1
    fi

    case "${METHOD}" in
        systemctl) restart_systemctl ;;
        docker)    restart_docker ;;
        kubectl)   restart_kubectl ;;
        *)         log_error "Unsupported method: ${METHOD}"; exit 1 ;;
    esac
}

main "$@"
