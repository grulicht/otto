#!/usr/bin/env bash
# OTTO - Fetch Terraform/OpenTofu state info
# Outputs structured JSON to stdout
set -euo pipefail

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/colors.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/error-handling.sh"

empty_result='{"workspaces":[],"resources_count":0,"last_apply":"","drift_detected":false}'

# Detect terraform or tofu
TF_CMD=""
if command -v terraform &>/dev/null; then
    TF_CMD="terraform"
elif command -v tofu &>/dev/null; then
    TF_CMD="tofu"
else
    log_debug "Neither terraform nor tofu found, skipping Terraform fetch"
    echo "${empty_result}"
    exit 0
fi

# Optional: working directory from arguments or OTTO_TF_DIR
TF_DIR="${1:-${OTTO_TF_DIR:-}}"
TF_ARGS=()
if [[ -n "${TF_DIR}" ]] && [[ -d "${TF_DIR}" ]]; then
    TF_ARGS=(-chdir="${TF_DIR}")
fi

# Check if terraform has been initialized
if ! "${TF_CMD}" "${TF_ARGS[@]}" state list &>/dev/null 2>&1; then
    log_warn "Terraform state not accessible (not initialized or no backend)"
    echo "${empty_result}"
    exit 0
fi

# Fetch workspaces
workspaces="[]"
if ws_output=$("${TF_CMD}" "${TF_ARGS[@]}" workspace list 2>/dev/null); then
    current_ws=$("${TF_CMD}" "${TF_ARGS[@]}" workspace show 2>/dev/null) || current_ws=""
    workspaces=$(echo "${ws_output}" | sed 's/^[* ]*//' | grep -v '^$' | jq -R -s --arg current "${current_ws}" \
        'split("\n") | map(select(length > 0) | ltrimstr(" ") | {
            name: .,
            active: (. == $current)
        })' 2>/dev/null) || workspaces="[]"
fi

# Count resources in state
resources_count=0
if state_list=$("${TF_CMD}" "${TF_ARGS[@]}" state list 2>/dev/null); then
    resources_count=$(echo "${state_list}" | grep -c '.' || true)
fi

# Last apply timestamp from state metadata
last_apply=""
if state_json=$("${TF_CMD}" "${TF_ARGS[@]}" show -json 2>/dev/null); then
    last_apply=$(echo "${state_json}" | jq -r '.values.root_module // empty | .resources // [] | .[0] // empty | empty' 2>/dev/null) || true
    # Fallback: check state file modification time
    if [[ -z "${last_apply}" ]]; then
        state_file="${TF_DIR:-.}/terraform.tfstate"
        if [[ -f "${state_file}" ]]; then
            last_apply=$(date -r "${state_file}" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || last_apply=""
        fi
    fi
fi

# Drift detection via plan
drift_detected=false
if plan_output=$("${TF_CMD}" "${TF_ARGS[@]}" plan -detailed-exitcode -no-color -input=false 2>/dev/null); then
    drift_detected=false
else
    plan_exit=$?
    if [[ "${plan_exit}" -eq 2 ]]; then
        drift_detected=true
        log_info "Terraform drift detected"
    else
        log_warn "Terraform plan failed (exit code ${plan_exit}), cannot determine drift"
    fi
fi

# Assemble final JSON
jq -n \
    --argjson workspaces "${workspaces}" \
    --argjson resources_count "${resources_count}" \
    --arg last_apply "${last_apply}" \
    --argjson drift_detected "${drift_detected}" \
    '{
        workspaces: $workspaces,
        resources_count: $resources_count,
        last_apply: $last_apply,
        drift_detected: $drift_detected
    }'
