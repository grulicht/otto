#!/usr/bin/env bash
# OTTO - Certificate renewal helper
# Supports: certbot renew, cert-manager trigger
# Usage: cert-renew.sh --domain <domain> [--method certbot|cert-manager] [--dry-run]
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

DOMAIN=""
METHOD=""
DRY_RUN=false
ENVIRONMENT=""
NAMESPACE=""
CERT_NAME=""
HOST=""
SSH_USER=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Renew a TLS certificate.

Options:
    --domain <domain>       Domain name to renew (required)
    --method <method>       Renewal method: certbot, cert-manager (auto-detected if omitted)
    --environment <env>     Environment name (optional, for permissions)
    --namespace <ns>        Kubernetes namespace (for cert-manager)
    --cert-name <name>      Certificate resource name (for cert-manager, defaults to domain)
    --host <host>           Remote host (for certbot via SSH)
    --ssh-user <user>       SSH user for remote operations
    --dry-run               Preview changes without applying
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)      DOMAIN="$2"; shift 2 ;;
            --method)      METHOD="$2"; shift 2 ;;
            --environment) ENVIRONMENT="$2"; shift 2 ;;
            --namespace)   NAMESPACE="$2"; shift 2 ;;
            --cert-name)   CERT_NAME="$2"; shift 2 ;;
            --host)        HOST="$2"; shift 2 ;;
            --ssh-user)    SSH_USER="$2"; shift 2 ;;
            --dry-run)     DRY_RUN=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${DOMAIN}" ]]; then
        log_error "Missing required argument: --domain"
        usage
        exit 1
    fi

    # Derive cert-manager resource name from domain if not specified
    CERT_NAME="${CERT_NAME:-$(echo "${DOMAIN}" | tr '.' '-' | sed 's/^\*-/wildcard-/')}"
}

detect_method() {
    if [[ -n "${METHOD}" ]]; then
        return
    fi

    if [[ -n "${NAMESPACE}" ]] && command -v kubectl &>/dev/null; then
        if kubectl get crd certificates.cert-manager.io &>/dev/null 2>&1; then
            METHOD="cert-manager"
        fi
    fi

    if [[ -z "${METHOD}" ]] && (command -v certbot &>/dev/null || [[ -n "${HOST}" ]]); then
        METHOD="certbot"
    fi

    if [[ -z "${METHOD}" ]]; then
        log_error "Cannot detect renewal method. Install certbot or cert-manager, or specify --method."
        exit 1
    fi

    log_info "Auto-detected renewal method: ${METHOD}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg method "${METHOD}" \
        --arg environment "${ENVIRONMENT:-}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
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

renew_certbot() {
    local host_display="${HOST:-localhost}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would renew certificate for ${DOMAIN} on ${host_display} via certbot"
        local output
        output=$(run_remote_or_local sudo certbot renew --cert-name "${DOMAIN}" --dry-run 2>&1) || true
        output_result "cert-renew" "${DOMAIN}" "dry-run" "Certbot dry-run: ${output}"
        return
    fi

    log_info "Renewing certificate for ${DOMAIN} on ${host_display} via certbot"
    local output
    output=$(run_remote_or_local sudo certbot renew --cert-name "${DOMAIN}" --no-random-sleep-on-renew 2>&1) || {
        # Try force-renew if regular renew says "not yet due"
        if echo "${output}" | grep -q "not yet due"; then
            log_info "Certificate not yet due for renewal, attempting force-renew"
            output=$(run_remote_or_local sudo certbot renew --cert-name "${DOMAIN}" --force-renewal 2>&1) || {
                output_result "cert-renew" "${DOMAIN}" "failed" "certbot renew failed: ${output}"
                exit 1
            }
        else
            output_result "cert-renew" "${DOMAIN}" "failed" "certbot renew failed: ${output}"
            exit 1
        fi
    }
    output_result "cert-renew" "${DOMAIN}" "success" "certbot renewal completed for ${DOMAIN} on ${host_display}"
}

renew_cert_manager() {
    local ns="${NAMESPACE:-default}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        local cert_status
        cert_status=$(kubectl -n "${ns}" get certificate "${CERT_NAME}" -o json 2>/dev/null | \
            jq -r '{ready: (.status.conditions // [] | map(select(.type == "Ready")) | .[0].status // "Unknown"), notAfter: .status.notAfter}' 2>/dev/null) || cert_status="unknown"
        log_info "[DRY-RUN] Would trigger cert-manager renewal for ${CERT_NAME} in ${ns}"
        log_info "Current certificate status: ${cert_status}"
        output_result "cert-renew" "${DOMAIN}" "dry-run" "Would trigger renewal for ${CERT_NAME} (status: ${cert_status})"
        return
    fi

    log_info "Triggering cert-manager renewal for ${CERT_NAME} in namespace ${ns}"

    # Delete the TLS secret to force re-issuance
    local secret_name
    secret_name=$(kubectl -n "${ns}" get certificate "${CERT_NAME}" -o json 2>/dev/null | \
        jq -r '.spec.secretName // empty' 2>/dev/null) || secret_name=""

    if [[ -n "${secret_name}" ]]; then
        local output
        output=$(kubectl -n "${ns}" delete secret "${secret_name}" 2>&1) || {
            output_result "cert-renew" "${DOMAIN}" "failed" "Failed to delete secret for re-issuance: ${output}"
            exit 1
        }
    else
        # Annotate to trigger renewal
        local output
        output=$(kubectl -n "${ns}" annotate certificate "${CERT_NAME}" \
            "cert-manager.io/renew-before=now" --overwrite 2>&1) || {
            output_result "cert-renew" "${DOMAIN}" "failed" "Failed to trigger cert-manager renewal: ${output}"
            exit 1
        }
    fi

    # Wait for certificate readiness (up to 120s)
    log_info "Waiting for certificate to be re-issued..."
    local ready="False"
    local attempts=0
    while [[ "${ready}" != "True" ]] && [[ "${attempts}" -lt 24 ]]; do
        sleep 5
        ready=$(kubectl -n "${ns}" get certificate "${CERT_NAME}" -o json 2>/dev/null | \
            jq -r '(.status.conditions // [] | map(select(.type == "Ready")) | .[0].status) // "False"' 2>/dev/null) || ready="False"
        attempts=$((attempts + 1))
    done

    if [[ "${ready}" == "True" ]]; then
        output_result "cert-renew" "${DOMAIN}" "success" "cert-manager renewal completed for ${CERT_NAME} in ${ns}"
    else
        output_result "cert-renew" "${DOMAIN}" "warning" "Renewal triggered but certificate not ready after 120s"
    fi
}

main() {
    parse_args "$@"
    detect_method

    local description="Renew TLS certificate for ${DOMAIN} via ${METHOD}"

    if ! permission_enforce "certificate" "renew" "${ENVIRONMENT}" "${description}"; then
        output_result "cert-renew" "${DOMAIN}" "denied" "Permission denied for certificate renewal"
        exit 1
    fi

    case "${METHOD}" in
        certbot)      renew_certbot ;;
        cert-manager) renew_cert_manager ;;
        *)            log_error "Unsupported method: ${METHOD}"; exit 1 ;;
    esac
}

main "$@"
