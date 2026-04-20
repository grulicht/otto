#!/usr/bin/env bash
# OTTO - Compliance-as-Code Engine
# Load, evaluate, and report on compliance policies defined in YAML.
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_COMPLIANCE_ENGINE_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_COMPLIANCE_ENGINE_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"

OTTO_POLICIES_FILE="${OTTO_DIR}/config/policies.yaml"
OTTO_POLICIES_STATE="${OTTO_HOME}/state/compliance"

# --- Internal helpers ---

_compliance_ensure_state() {
    mkdir -p "${OTTO_POLICIES_STATE}"
}

# --- Public API ---

# Load policy definitions from a YAML file.
# Usage: policy_load <file>
policy_load() {
    local file="${1:-${OTTO_POLICIES_FILE}}"

    if [[ ! -f "${file}" ]]; then
        log_error "Policy file not found: ${file}"
        return 1
    fi

    if ! command -v yq &>/dev/null; then
        log_error "yq is required for policy loading"
        return 1
    fi

    local count
    count=$(yq eval '.policies | length' "${file}" 2>/dev/null) || {
        log_error "Failed to parse policy file: ${file}"
        return 1
    }

    log_info "Loaded ${count} policies from ${file}"
    echo "${count}"
}

# Evaluate a single policy against its target.
# Usage: policy_evaluate <policy_name> [policy_file]
policy_evaluate() {
    local policy_name="$1"
    local file="${2:-${OTTO_POLICIES_FILE}}"

    if [[ ! -f "${file}" ]]; then
        log_error "Policy file not found: ${file}"
        return 1
    fi

    local policy
    policy=$(yq eval ".policies[] | select(.name == \"${policy_name}\")" "${file}" -o json 2>/dev/null)

    if [[ -z "${policy}" || "${policy}" == "null" ]]; then
        log_error "Policy not found: ${policy_name}"
        return 1
    fi

    local check expected severity description
    check=$(echo "${policy}" | jq -r '.check // ""')
    expected=$(echo "${policy}" | jq -r '.expected // ""')
    severity=$(echo "${policy}" | jq -r '.severity // "medium"')
    description=$(echo "${policy}" | jq -r '.description // ""')

    local result="unknown"
    local actual_value=""

    # Execute the check command
    if [[ -n "${check}" ]]; then
        actual_value=$(eval "${check}" 2>/dev/null) || actual_value="error"

        if [[ -n "${expected}" ]]; then
            if [[ "${actual_value}" == "${expected}" ]]; then
                result="pass"
            else
                result="fail"
            fi
        else
            # No expected value - just check command succeeded
            if [[ "${actual_value}" != "error" ]]; then
                result="pass"
            else
                result="fail"
            fi
        fi
    fi

    _compliance_ensure_state
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq -n --arg name "${policy_name}" --arg desc "${description}" \
        --arg result "${result}" --arg severity "${severity}" \
        --arg actual "${actual_value}" --arg expected "${expected}" \
        --arg ts "${ts}" \
        '{
            policy: $name,
            description: $desc,
            result: $result,
            severity: $severity,
            actual_value: $actual,
            expected_value: $expected,
            evaluated_at: $ts
        }' | tee "${OTTO_POLICIES_STATE}/${policy_name}.json"
}

# Evaluate all policies in the policy file.
# Usage: policy_evaluate_all [policy_file]
policy_evaluate_all() {
    local file="${1:-${OTTO_POLICIES_FILE}}"

    if [[ ! -f "${file}" ]]; then
        log_error "Policy file not found: ${file}"
        return 1
    fi

    local names
    names=$(yq eval '.policies[].name' "${file}" 2>/dev/null) || {
        log_error "Failed to parse policies"
        return 1
    }

    local results="[]"
    while IFS= read -r name; do
        [[ -z "${name}" ]] && continue
        log_info "Evaluating policy: ${name}"
        local result
        result=$(policy_evaluate "${name}" "${file}" 2>/dev/null) || result='{"policy":"'"${name}"'","result":"error"}'
        results=$(echo "${results}" | jq --argjson r "${result}" '. + [$r]')
    done <<< "${names}"

    echo "${results}" | jq .
}

# Generate a compliance report summarizing all policy evaluations.
# Usage: policy_report [policy_file]
policy_report() {
    local file="${1:-${OTTO_POLICIES_FILE}}"

    local results
    results=$(policy_evaluate_all "${file}" 2>/dev/null) || results='[]'

    local total passed failed errors
    total=$(echo "${results}" | jq 'length')
    passed=$(echo "${results}" | jq '[.[] | select(.result == "pass")] | length')
    failed=$(echo "${results}" | jq '[.[] | select(.result == "fail")] | length')
    errors=$(echo "${results}" | jq '[.[] | select(.result == "error" or .result == "unknown")] | length')

    local critical_failures
    critical_failures=$(echo "${results}" | jq '[.[] | select(.result == "fail" and .severity == "critical")]')

    jq -n --argjson results "${results}" --argjson total "${total}" \
        --argjson passed "${passed}" --argjson failed "${failed}" --argjson errors "${errors}" \
        --argjson critical "${critical_failures}" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            timestamp: $ts,
            summary: {
                total: $total,
                passed: $passed,
                failed: $failed,
                errors: $errors,
                compliance_percent: (if $total > 0 then ($passed / $total * 100 | floor) else 0 end)
            },
            critical_failures: $critical,
            details: $results
        }'
}

# Add a new policy to the policy file.
# Usage: policy_add <name> <check> <severity> <auto_fix>
policy_add() {
    local name="$1"
    local check="$2"
    local severity="${3:-medium}"
    local auto_fix="${4:-false}"

    local file="${OTTO_POLICIES_FILE}"

    if ! command -v yq &>/dev/null; then
        log_error "yq is required for policy management"
        return 1
    fi

    # Check if policy already exists
    local existing
    existing=$(yq eval ".policies[] | select(.name == \"${name}\") | .name" "${file}" 2>/dev/null) || existing=""
    if [[ -n "${existing}" ]]; then
        log_error "Policy '${name}' already exists"
        return 1
    fi

    yq eval -i ".policies += [{\"name\": \"${name}\", \"check\": \"${check}\", \"severity\": \"${severity}\", \"auto_fix\": ${auto_fix}}]" "${file}" 2>/dev/null || {
        log_error "Failed to add policy"
        return 1
    }

    log_info "Policy '${name}' added with severity=${severity}"
}

# List all configured policies.
# Usage: policy_list [policy_file]
policy_list() {
    local file="${1:-${OTTO_POLICIES_FILE}}"

    if [[ ! -f "${file}" ]]; then
        log_error "Policy file not found: ${file}"
        return 1
    fi

    yq eval '.policies[] | {"name": .name, "severity": .severity, "domain": .domain}' "${file}" -o json 2>/dev/null \
        | jq -s .
}
