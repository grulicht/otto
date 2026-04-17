#!/usr/bin/env bash
# OTTO - Rollback helper
# Supports: kubectl rollout undo, helm rollback, argocd rollback
# Usage: rollback.sh --target <target> --environment <env> [--revision <rev>] [--method kubectl|helm|argocd] [--dry-run]
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

TARGET=""
ENVIRONMENT=""
REVISION=""
METHOD=""
DRY_RUN=false
NAMESPACE=""
RESOURCE_TYPE="deployment"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Rollback an application to a previous version.

Options:
    --target <name>         Application or service name (required)
    --environment <env>     Target environment (required)
    --revision <rev>        Revision to rollback to (optional, defaults to previous)
    --method <method>       Rollback method: kubectl, helm, argocd (auto-detected if omitted)
    --namespace <ns>        Kubernetes namespace (defaults to target name)
    --resource-type <type>  Resource type: deployment, statefulset, daemonset (default: deployment)
    --dry-run               Preview changes without applying
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)        TARGET="$2"; shift 2 ;;
            --environment)   ENVIRONMENT="$2"; shift 2 ;;
            --revision)      REVISION="$2"; shift 2 ;;
            --method)        METHOD="$2"; shift 2 ;;
            --namespace)     NAMESPACE="$2"; shift 2 ;;
            --resource-type) RESOURCE_TYPE="$2"; shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TARGET}" ]] || [[ -z "${ENVIRONMENT}" ]]; then
        log_error "Missing required arguments: --target and --environment are required"
        usage
        exit 1
    fi

    NAMESPACE="${NAMESPACE:-${TARGET}}"
}

detect_method() {
    if [[ -n "${METHOD}" ]]; then
        return
    fi

    if command -v helm &>/dev/null && helm status "${TARGET}" -n "${NAMESPACE}" &>/dev/null 2>&1; then
        METHOD="helm"
    elif command -v argocd &>/dev/null && argocd app get "${TARGET}" &>/dev/null 2>&1; then
        METHOD="argocd"
    elif command -v kubectl &>/dev/null; then
        METHOD="kubectl"
    else
        log_error "No rollback tool found. Install kubectl, helm, or argocd."
        exit 1
    fi

    log_info "Auto-detected rollback method: ${METHOD}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg environment "${ENVIRONMENT}" \
        --arg revision "${REVISION:-previous}" \
        --arg method "${METHOD}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            environment: $environment,
            revision: $revision,
            method: $method,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

rollback_kubectl() {
    local cmd=(kubectl -n "${NAMESPACE}" rollout undo "${RESOURCE_TYPE}/${TARGET}")
    [[ -n "${REVISION}" ]] && cmd+=(--to-revision="${REVISION}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would run: ${cmd[*]}"
        log_info "Current rollout history:"
        kubectl -n "${NAMESPACE}" rollout history "${RESOURCE_TYPE}/${TARGET}" 2>&1 || true
        output_result "rollback" "${TARGET}" "dry-run" "Would rollback ${RESOURCE_TYPE}/${TARGET} to revision ${REVISION:-previous}"
        return
    fi

    log_info "Rolling back ${TARGET} in ${ENVIRONMENT} via kubectl"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "rollback" "${TARGET}" "failed" "kubectl rollout undo failed: ${output}"
        exit 1
    }
    kubectl -n "${NAMESPACE}" rollout status "${RESOURCE_TYPE}/${TARGET}" --timeout=300s 2>&1 || true
    output_result "rollback" "${TARGET}" "success" "kubectl rollout undo completed: ${output}"
}

rollback_helm() {
    local revision="${REVISION:-}"

    if [[ -z "${revision}" ]]; then
        local current
        current=$(helm history "${TARGET}" -n "${NAMESPACE}" -o json 2>/dev/null | \
            jq -r 'sort_by(.revision) | last.revision' 2>/dev/null) || current=""
        if [[ -n "${current}" ]] && [[ "${current}" -gt 1 ]]; then
            revision=$((current - 1))
        else
            log_error "Cannot determine previous revision for helm rollback"
            exit 1
        fi
    fi

    local cmd=(helm rollback "${TARGET}" "${revision}" --namespace "${NAMESPACE}")
    if [[ "${DRY_RUN}" == "true" ]]; then
        cmd+=(--dry-run)
        log_info "[DRY-RUN] Would run: ${cmd[*]}"
    fi

    log_info "Rolling back ${TARGET} in ${ENVIRONMENT} to helm revision ${revision}"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "rollback" "${TARGET}" "failed" "helm rollback failed: ${output}"
        exit 1
    }
    output_result "rollback" "${TARGET}" "success" "helm rollback to revision ${revision} completed"
}

rollback_argocd() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would rollback ArgoCD app: ${TARGET}"
        log_info "Current deployment history:"
        argocd app history "${TARGET}" 2>&1 || true
        output_result "rollback" "${TARGET}" "dry-run" "Would rollback ArgoCD app ${TARGET} to revision ${REVISION:-previous}"
        return
    fi

    log_info "Rolling back ${TARGET} in ${ENVIRONMENT} via argocd"
    local rollback_target="${REVISION:-}"

    if [[ -z "${rollback_target}" ]]; then
        rollback_target=$(argocd app history "${TARGET}" -o json 2>/dev/null | \
            jq -r 'sort_by(.id) | .[-2].id // empty' 2>/dev/null) || rollback_target=""
        if [[ -z "${rollback_target}" ]]; then
            log_error "Cannot determine previous ArgoCD deployment for rollback"
            exit 1
        fi
    fi

    local output
    output=$(argocd app rollback "${TARGET}" "${rollback_target}" 2>&1) || {
        output_result "rollback" "${TARGET}" "failed" "argocd rollback failed: ${output}"
        exit 1
    }
    output_result "rollback" "${TARGET}" "success" "argocd rollback completed for ${TARGET}"
}

main() {
    parse_args "$@"
    detect_method

    local description="Rollback ${TARGET} in ${ENVIRONMENT} to revision ${REVISION:-previous} via ${METHOD}"

    if ! permission_enforce "deployment" "rollback" "${ENVIRONMENT}" "${description}"; then
        output_result "rollback" "${TARGET}" "denied" "Permission denied for rollback in ${ENVIRONMENT}"
        exit 1
    fi

    case "${METHOD}" in
        kubectl) rollback_kubectl ;;
        helm)    rollback_helm ;;
        argocd)  rollback_argocd ;;
        *)       log_error "Unsupported method: ${METHOD}"; exit 1 ;;
    esac
}

main "$@"
