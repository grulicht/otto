#!/usr/bin/env bash
# OTTO - Infrastructure Drift Reconciliation
# Detects and reconciles drift in Terraform, Kubernetes, and Ansible
# Usage: reconcile.sh --target <path_or_name> --type terraform|kubernetes|ansible --environment <env> [--dry-run]
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source required libraries
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
DRIFT_TYPE=""
ENVIRONMENT=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Detect and reconcile infrastructure drift.

Options:
    --target <path_or_name>     Target path or resource name (required)
    --type <type>               Drift type: terraform, kubernetes, ansible (required)
    --environment <env>         Target environment: production, staging, development (required)
    --dry-run                   Detect drift only, do not apply changes
    -h, --help                  Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)      TARGET="$2"; shift 2 ;;
            --type)        DRIFT_TYPE="$2"; shift 2 ;;
            --environment) ENVIRONMENT="$2"; shift 2 ;;
            --dry-run)     DRY_RUN=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             log_error "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TARGET}" ]]; then
        log_error "Missing required argument: --target"
        usage
        exit 1
    fi
    if [[ -z "${DRIFT_TYPE}" ]]; then
        log_error "Missing required argument: --type"
        usage
        exit 1
    fi
    if [[ -z "${ENVIRONMENT}" ]]; then
        log_error "Missing required argument: --environment"
        usage
        exit 1
    fi

    case "${DRIFT_TYPE}" in
        terraform|kubernetes|ansible) ;;
        *)
            log_error "Invalid type: ${DRIFT_TYPE}. Must be terraform, kubernetes, or ansible."
            exit 1
            ;;
    esac
}

# --- JSON output helper ---
_output_result() {
    local status="$1"
    local drift_detected="$2"
    local message="$3"
    local details="${4:-{}}"

    jq -n \
        --arg status "${status}" \
        --argjson drift "${drift_detected}" \
        --arg message "${message}" \
        --argjson details "${details}" \
        --arg target "${TARGET}" \
        --arg type "${DRIFT_TYPE}" \
        --arg environment "${ENVIRONMENT}" \
        --argjson dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            timestamp: $timestamp,
            action: "reconcile",
            target: $target,
            type: $type,
            environment: $environment,
            dry_run: $dry_run,
            status: $status,
            drift_detected: $drift,
            message: $message,
            details: $details
        }'
}

# --- Terraform reconciliation ---
_reconcile_terraform() {
    local target_dir="${TARGET}"

    if [[ ! -d "${target_dir}" ]]; then
        _output_result "error" false "Terraform directory not found: ${target_dir}"
        return 1
    fi

    log_info "Running terraform plan to detect drift..."

    local plan_output
    local plan_exit=0

    if ! plan_output=$(cd "${target_dir}" && terraform plan -detailed-exitcode -no-color 2>&1); then
        plan_exit=$?
    fi

    case ${plan_exit} in
        0)
            log_info "No drift detected in Terraform state."
            _output_result "success" false "No infrastructure drift detected" \
                "$(jq -n --arg output "${plan_output}" '{plan_output: $output}')"
            ;;
        2)
            log_warn "Drift detected in Terraform state!"
            local drift_details
            drift_details=$(jq -n --arg output "${plan_output}" '{plan_output: $output, changes_pending: true}')

            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "Dry run mode - not applying changes."
                _output_result "drift_detected" true "Drift detected (dry-run, no changes applied)" "${drift_details}"
            else
                # Check permissions before applying
                local perm
                perm=$(permission_resolve "terraform" "apply" "${ENVIRONMENT}")
                if ! permission_enforce "terraform" "apply" "${ENVIRONMENT}" \
                    "Apply Terraform changes to reconcile drift in ${ENVIRONMENT}"; then
                    _output_result "denied" true "Drift detected but permission denied for apply" "${drift_details}"
                    return 1
                fi

                log_info "Applying Terraform changes..."
                local apply_output
                if apply_output=$(cd "${target_dir}" && terraform apply -auto-approve -no-color 2>&1); then
                    _output_result "reconciled" true "Drift detected and reconciled" \
                        "$(jq -n --arg plan "${plan_output}" --arg apply "${apply_output}" \
                            '{plan_output: $plan, apply_output: $apply}')"
                else
                    _output_result "error" true "Drift detected but apply failed" \
                        "$(jq -n --arg plan "${plan_output}" --arg apply "${apply_output}" \
                            '{plan_output: $plan, apply_output: $apply}')"
                    return 1
                fi
            fi
            ;;
        *)
            _output_result "error" false "Terraform plan failed" \
                "$(jq -n --arg output "${plan_output}" --argjson exit_code "${plan_exit}" \
                    '{plan_output: $output, exit_code: $exit_code}')"
            return 1
            ;;
    esac
}

# --- Kubernetes reconciliation ---
_reconcile_kubernetes() {
    local manifest_path="${TARGET}"

    if [[ ! -e "${manifest_path}" ]]; then
        _output_result "error" false "Kubernetes manifest not found: ${manifest_path}"
        return 1
    fi

    log_info "Comparing desired Kubernetes state with live state..."

    local diff_output
    local diff_exit=0

    if ! diff_output=$(kubectl diff -f "${manifest_path}" 2>&1); then
        diff_exit=$?
    fi

    case ${diff_exit} in
        0)
            log_info "No drift detected in Kubernetes resources."
            _output_result "success" false "No drift detected in Kubernetes resources"
            ;;
        1)
            log_warn "Drift detected in Kubernetes resources!"
            local drift_details
            drift_details=$(jq -n --arg output "${diff_output}" '{diff_output: $output}')

            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "Dry run mode - not applying changes."
                _output_result "drift_detected" true "Drift detected (dry-run, no changes applied)" "${drift_details}"
            else
                local perm
                perm=$(permission_resolve "kubernetes" "apply" "${ENVIRONMENT}")
                if ! permission_enforce "kubernetes" "apply" "${ENVIRONMENT}" \
                    "Apply Kubernetes manifests to reconcile drift in ${ENVIRONMENT}"; then
                    _output_result "denied" true "Drift detected but permission denied for apply" "${drift_details}"
                    return 1
                fi

                log_info "Applying Kubernetes manifests..."
                local apply_output
                if apply_output=$(kubectl apply -f "${manifest_path}" 2>&1); then
                    _output_result "reconciled" true "Drift detected and reconciled" \
                        "$(jq -n --arg diff "${diff_output}" --arg apply "${apply_output}" \
                            '{diff_output: $diff, apply_output: $apply}')"
                else
                    _output_result "error" true "Drift detected but apply failed" \
                        "$(jq -n --arg diff "${diff_output}" --arg apply "${apply_output}" \
                            '{diff_output: $diff, apply_output: $apply}')"
                    return 1
                fi
            fi
            ;;
        *)
            _output_result "error" false "kubectl diff failed" \
                "$(jq -n --arg output "${diff_output}" --argjson exit_code "${diff_exit}" \
                    '{diff_output: $output, exit_code: $exit_code}')"
            return 1
            ;;
    esac
}

# --- Ansible reconciliation ---
_reconcile_ansible() {
    local playbook="${TARGET}"

    if [[ ! -f "${playbook}" ]]; then
        _output_result "error" false "Ansible playbook not found: ${playbook}"
        return 1
    fi

    log_info "Running Ansible in check mode to detect drift..."

    local check_output
    local check_exit=0

    if ! check_output=$(ansible-playbook "${playbook}" --check --diff 2>&1); then
        check_exit=$?
    fi

    # Parse changed/failed counts from Ansible output
    local changed_count
    changed_count=$(echo "${check_output}" | grep -oP 'changed=\K[0-9]+' | tail -1 || echo "0")

    if [[ "${changed_count}" == "0" && ${check_exit} -eq 0 ]]; then
        log_info "No drift detected by Ansible."
        _output_result "success" false "No configuration drift detected" \
            "$(jq -n --arg output "${check_output}" '{check_output: $output}')"
    else
        log_warn "Drift detected by Ansible (${changed_count} changes needed)!"
        local drift_details
        drift_details=$(jq -n --arg output "${check_output}" --arg changes "${changed_count}" \
            '{check_output: $output, changes_needed: ($changes | tonumber)}')

        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Dry run mode - not applying changes."
            _output_result "drift_detected" true "Drift detected (dry-run, no changes applied)" "${drift_details}"
        else
            if ! permission_enforce "ansible" "apply" "${ENVIRONMENT}" \
                "Run Ansible playbook to reconcile drift in ${ENVIRONMENT}"; then
                _output_result "denied" true "Drift detected but permission denied for apply" "${drift_details}"
                return 1
            fi

            log_info "Running Ansible playbook..."
            local apply_output
            if apply_output=$(ansible-playbook "${playbook}" --diff 2>&1); then
                _output_result "reconciled" true "Drift detected and reconciled" \
                    "$(jq -n --arg check "${check_output}" --arg apply "${apply_output}" \
                        '{check_output: $check, apply_output: $apply}')"
            else
                _output_result "error" true "Drift detected but playbook run failed" \
                    "$(jq -n --arg check "${check_output}" --arg apply "${apply_output}" \
                        '{check_output: $check, apply_output: $apply}')"
                return 1
            fi
        fi
    fi
}

# --- Main ---
main() {
    parse_args "$@"

    log_info "Starting drift reconciliation: type=${DRIFT_TYPE} target=${TARGET} env=${ENVIRONMENT} dry_run=${DRY_RUN}"

    case "${DRIFT_TYPE}" in
        terraform)  _reconcile_terraform ;;
        kubernetes) _reconcile_kubernetes ;;
        ansible)    _reconcile_ansible ;;
    esac
}

main "$@"
