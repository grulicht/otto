#!/usr/bin/env bash
# OTTO - Generic deployment helper
# Supports: kubectl apply, helm upgrade, argocd sync
# Usage: deploy.sh --target <target> --environment <env> --version <version> [--method kubectl|helm|argocd] [--dry-run]
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
VERSION=""
METHOD=""
DRY_RUN=false
NAMESPACE=""
HELM_CHART=""
HELM_VALUES=""
ARGOCD_APP=""
KUBECTL_MANIFEST=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy an application to a target environment.

Options:
    --target <name>         Application or service name (required)
    --environment <env>     Target environment: production, staging, development (required)
    --version <version>     Version to deploy (required)
    --method <method>       Deployment method: kubectl, helm, argocd (auto-detected if omitted)
    --namespace <ns>        Kubernetes namespace (defaults to target name)
    --chart <chart>         Helm chart reference (for helm method)
    --values <file>         Helm values file (for helm method)
    --app <name>            ArgoCD application name (for argocd method)
    --manifest <path>       Kubernetes manifest path (for kubectl method)
    --dry-run               Preview changes without applying
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)      TARGET="$2"; shift 2 ;;
            --environment) ENVIRONMENT="$2"; shift 2 ;;
            --version)     VERSION="$2"; shift 2 ;;
            --method)      METHOD="$2"; shift 2 ;;
            --namespace)   NAMESPACE="$2"; shift 2 ;;
            --chart)       HELM_CHART="$2"; shift 2 ;;
            --values)      HELM_VALUES="$2"; shift 2 ;;
            --app)         ARGOCD_APP="$2"; shift 2 ;;
            --manifest)    KUBECTL_MANIFEST="$2"; shift 2 ;;
            --dry-run)     DRY_RUN=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TARGET}" ]] || [[ -z "${ENVIRONMENT}" ]] || [[ -z "${VERSION}" ]]; then
        log_error "Missing required arguments: --target, --environment, and --version are required"
        usage
        exit 1
    fi

    NAMESPACE="${NAMESPACE:-${TARGET}}"
    ARGOCD_APP="${ARGOCD_APP:-${TARGET}}"
}

detect_method() {
    if [[ -n "${METHOD}" ]]; then
        return
    fi

    if [[ -n "${HELM_CHART}" ]] && command -v helm &>/dev/null; then
        METHOD="helm"
    elif command -v helm &>/dev/null && helm status "${TARGET}" -n "${NAMESPACE}" &>/dev/null 2>&1; then
        METHOD="helm"
    elif command -v argocd &>/dev/null && argocd app get "${ARGOCD_APP}" &>/dev/null 2>&1; then
        METHOD="argocd"
    elif command -v kubectl &>/dev/null; then
        METHOD="kubectl"
    else
        log_error "No deployment tool found. Install kubectl, helm, or argocd."
        exit 1
    fi

    log_info "Auto-detected deployment method: ${METHOD}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg environment "${ENVIRONMENT}" \
        --arg version "${VERSION}" \
        --arg method "${METHOD}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            environment: $environment,
            version: $version,
            method: $method,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

deploy_kubectl() {
    if [[ -n "${KUBECTL_MANIFEST}" ]]; then
        # Apply manifest file
        local cmd=(kubectl apply -n "${NAMESPACE}" -f "${KUBECTL_MANIFEST}")
        if [[ "${DRY_RUN}" == "true" ]]; then
            cmd+=(--dry-run=client)
            log_info "[DRY-RUN] Would run: ${cmd[*]}"
        fi

        log_info "Deploying ${TARGET} v${VERSION} to ${ENVIRONMENT} via kubectl apply"
        local output
        output=$("${cmd[@]}" 2>&1) || {
            output_result "deploy" "${TARGET}" "failed" "kubectl apply failed: ${output}"
            exit 1
        }
        output_result "deploy" "${TARGET}" "success" "kubectl apply completed: ${output}"
    else
        # Update image tag on existing deployment
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would set image ${TARGET}=${TARGET}:${VERSION} on deployment/${TARGET} in ${NAMESPACE}"
            output_result "deploy" "${TARGET}" "dry-run" "Would set image to ${TARGET}:${VERSION}"
            return
        fi

        log_info "Deploying ${TARGET} v${VERSION} to ${ENVIRONMENT} via kubectl set image"
        local output
        output=$(kubectl set image "deployment/${TARGET}" "${TARGET}=${TARGET}:${VERSION}" -n "${NAMESPACE}" 2>&1) || {
            output_result "deploy" "${TARGET}" "failed" "kubectl set image failed: ${output}"
            exit 1
        }
        kubectl rollout status "deployment/${TARGET}" -n "${NAMESPACE}" --timeout=300s 2>&1 || true
        output_result "deploy" "${TARGET}" "success" "kubectl set image completed: ${output}"
    fi
}

deploy_helm() {
    local chart="${HELM_CHART:-${TARGET}}"
    local cmd=(helm upgrade --install "${TARGET}" "${chart}"
        --namespace "${NAMESPACE}"
        --set "image.tag=${VERSION}"
    )

    [[ -n "${HELM_VALUES}" ]] && cmd+=(--values "${HELM_VALUES}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        cmd+=(--dry-run)
        log_info "[DRY-RUN] Would run: ${cmd[*]}"
    fi

    log_info "Deploying ${TARGET} v${VERSION} to ${ENVIRONMENT} via helm"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "deploy" "${TARGET}" "failed" "helm upgrade failed: ${output}"
        exit 1
    }
    output_result "deploy" "${TARGET}" "success" "helm upgrade completed"
}

deploy_argocd() {
    local app="${ARGOCD_APP}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would sync ArgoCD app: ${app}"
        local output
        output=$(argocd app diff "${app}" 2>&1) || true
        output_result "deploy" "${TARGET}" "dry-run" "argocd diff: ${output}"
        return
    fi

    log_info "Deploying ${TARGET} v${VERSION} to ${ENVIRONMENT} via argocd sync"
    local output
    output=$(argocd app sync "${app}" --revision "${VERSION}" 2>&1) || {
        output_result "deploy" "${TARGET}" "failed" "argocd sync failed: ${output}"
        exit 1
    }
    argocd app wait "${app}" --timeout 300 2>&1 || true
    output_result "deploy" "${TARGET}" "success" "argocd sync completed for ${app}"
}

main() {
    parse_args "$@"
    detect_method

    local description="Deploy ${TARGET} v${VERSION} to ${ENVIRONMENT} via ${METHOD}"

    if ! permission_enforce "deployment" "deploy" "${ENVIRONMENT}" "${description}"; then
        output_result "deploy" "${TARGET}" "denied" "Permission denied for deployment to ${ENVIRONMENT}"
        exit 1
    fi

    case "${METHOD}" in
        kubectl) deploy_kubectl ;;
        helm)    deploy_helm ;;
        argocd)  deploy_argocd ;;
        *)       log_error "Unsupported method: ${METHOD}"; exit 1 ;;
    esac
}

main "$@"
