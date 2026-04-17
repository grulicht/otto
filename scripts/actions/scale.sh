#!/usr/bin/env bash
# OTTO - Scaling helper
# Supports: kubectl scale, AWS auto-scaling groups
# Usage: scale.sh --target <target> --replicas <count> --environment <env> [--method kubectl|aws-asg] [--dry-run]
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
REPLICAS=""
ENVIRONMENT=""
METHOD=""
DRY_RUN=false
NAMESPACE=""
RESOURCE_TYPE="deployment"
ASG_MIN=""
ASG_MAX=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scale an application or auto-scaling group.

Options:
    --target <name>         Deployment or ASG name (required)
    --replicas <count>      Desired replica count (required)
    --environment <env>     Target environment (required)
    --method <method>       Scaling method: kubectl, aws-asg (auto-detected if omitted)
    --namespace <ns>        Kubernetes namespace (defaults to target name)
    --resource-type <type>  Resource type: deployment, statefulset, replicaset (default: deployment)
    --asg-min <count>       ASG minimum size (for aws-asg, defaults to replicas)
    --asg-max <count>       ASG maximum size (for aws-asg, defaults to replicas)
    --dry-run               Preview changes without applying
    -h, --help              Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)        TARGET="$2"; shift 2 ;;
            --replicas)      REPLICAS="$2"; shift 2 ;;
            --environment)   ENVIRONMENT="$2"; shift 2 ;;
            --method)        METHOD="$2"; shift 2 ;;
            --namespace)     NAMESPACE="$2"; shift 2 ;;
            --resource-type) RESOURCE_TYPE="$2"; shift 2 ;;
            --asg-min)       ASG_MIN="$2"; shift 2 ;;
            --asg-max)       ASG_MAX="$2"; shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "${TARGET}" ]] || [[ -z "${REPLICAS}" ]] || [[ -z "${ENVIRONMENT}" ]]; then
        log_error "Missing required arguments: --target, --replicas, and --environment are required"
        usage
        exit 1
    fi

    if ! [[ "${REPLICAS}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid replica count: ${REPLICAS} (must be a non-negative integer)"
        exit 1
    fi

    NAMESPACE="${NAMESPACE:-${TARGET}}"
}

detect_method() {
    if [[ -n "${METHOD}" ]]; then
        return
    fi

    if command -v kubectl &>/dev/null; then
        METHOD="kubectl"
    elif command -v aws &>/dev/null; then
        METHOD="aws-asg"
    else
        log_error "No scaling tool found. Install kubectl or aws CLI."
        exit 1
    fi

    log_info "Auto-detected scaling method: ${METHOD}"
}

output_result() {
    local action="$1" target="$2" status="$3" details="$4"
    jq -n \
        --arg action "${action}" \
        --arg target "${target}" \
        --arg status "${status}" \
        --arg details "${details}" \
        --arg environment "${ENVIRONMENT}" \
        --arg replicas "${REPLICAS}" \
        --arg method "${METHOD}" \
        --arg dry_run "${DRY_RUN}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            action: $action,
            target: $target,
            status: $status,
            details: $details,
            environment: $environment,
            replicas: ($replicas | tonumber),
            method: $method,
            dry_run: ($dry_run == "true"),
            timestamp: $timestamp
        }'
}

scale_kubectl() {
    local current
    current=$(kubectl -n "${NAMESPACE}" get "${RESOURCE_TYPE}/${TARGET}" -o json 2>/dev/null | \
        jq -r '.spec.replicas // "unknown"' 2>/dev/null) || current="unknown"

    local cmd=(kubectl -n "${NAMESPACE}" scale "${RESOURCE_TYPE}/${TARGET}" "--replicas=${REPLICAS}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        cmd+=(--dry-run=client)
        log_info "[DRY-RUN] Would scale ${TARGET} from ${current} to ${REPLICAS} replicas"
        output_result "scale" "${TARGET}" "dry-run" "Would scale from ${current} to ${REPLICAS} replicas"
        return
    fi

    log_info "Scaling ${TARGET} in ${ENVIRONMENT} from ${current} to ${REPLICAS} replicas"
    local output
    output=$("${cmd[@]}" 2>&1) || {
        output_result "scale" "${TARGET}" "failed" "kubectl scale failed: ${output}"
        exit 1
    }
    output_result "scale" "${TARGET}" "success" "Scaled from ${current} to ${REPLICAS} replicas: ${output}"
}

scale_aws_asg() {
    local min="${ASG_MIN:-${REPLICAS}}"
    local max="${ASG_MAX:-${REPLICAS}}"

    local current_desired="unknown"
    local current_asg
    if current_asg=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${TARGET}" --output json 2>/dev/null); then
        current_desired=$(echo "${current_asg}" | jq -r '.AutoScalingGroups[0].DesiredCapacity // "unknown"')
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would update ASG ${TARGET}: desired=${REPLICAS}, min=${min}, max=${max}"
        log_info "Current desired capacity: ${current_desired}"
        output_result "scale" "${TARGET}" "dry-run" "Would scale ASG from ${current_desired} to ${REPLICAS} (min=${min}, max=${max})"
        return
    fi

    log_info "Scaling ASG ${TARGET} in ${ENVIRONMENT}: desired=${REPLICAS}, min=${min}, max=${max}"
    local output
    output=$(aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "${TARGET}" \
        --desired-capacity "${REPLICAS}" \
        --min-size "${min}" \
        --max-size "${max}" 2>&1) || {
        output_result "scale" "${TARGET}" "failed" "AWS ASG update failed: ${output}"
        exit 1
    }
    output_result "scale" "${TARGET}" "success" "ASG scaled from ${current_desired} to ${REPLICAS} (min=${min}, max=${max})"
}

main() {
    parse_args "$@"
    detect_method

    local description="Scale ${TARGET} to ${REPLICAS} replicas in ${ENVIRONMENT} via ${METHOD}"

    if ! permission_enforce "deployment" "scale" "${ENVIRONMENT}" "${description}"; then
        output_result "scale" "${TARGET}" "denied" "Permission denied for scaling in ${ENVIRONMENT}"
        exit 1
    fi

    case "${METHOD}" in
        kubectl) scale_kubectl ;;
        aws-asg) scale_aws_asg ;;
        *)       log_error "Unsupported method: ${METHOD}"; exit 1 ;;
    esac
}

main "$@"
