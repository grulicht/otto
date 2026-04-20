#!/usr/bin/env bash
# OTTO - Configuration schema validation
set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_OTTO_CONFIG_SCHEMA_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_OTTO_CONFIG_SCHEMA_LOADED=1

OTTO_DIR="${OTTO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"

# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/logging.sh"
# shellcheck source=/dev/null
source "${OTTO_DIR}/scripts/lib/yaml-utils.sh"

# --- Internal ---

# Known required fields and their expected types
declare -A _SCHEMA_REQUIRED_FIELDS=(
    [".language"]="string"
    [".permission_profile"]="string"
    [".log_level"]="enum:debug,info,warn,error"
)

# Known enum values
declare -A _SCHEMA_ENUMS=(
    [".permission_profile"]="beginner,balanced,autonomous,paranoid,team-default"
    [".log_level"]="debug,info,warn,error"
    [".night_watcher.enabled"]="true,false"
)

_schema_check_required() {
    local config_file="$1"
    local errors="$2"

    for field in "${!_SCHEMA_REQUIRED_FIELDS[@]}"; do
        local value
        value=$(yq eval "${field}" "${config_file}" 2>/dev/null) || value=""
        if [[ -z "${value}" || "${value}" == "null" ]]; then
            errors="${errors}Missing required field: ${field}\n"
        fi
    done

    echo -e "${errors}"
}

_schema_check_enums() {
    local config_file="$1"
    local errors="$2"

    for field in "${!_SCHEMA_ENUMS[@]}"; do
        local value
        value=$(yq eval "${field}" "${config_file}" 2>/dev/null) || value=""
        if [[ -z "${value}" || "${value}" == "null" ]]; then
            continue  # Skip if not set (required check handles that)
        fi

        local valid_values="${_SCHEMA_ENUMS[${field}]}"
        local found=false
        IFS=',' read -ra vals <<< "${valid_values}"
        for v in "${vals[@]}"; do
            if [[ "${value}" == "${v}" ]]; then
                found=true
                break
            fi
        done

        if [[ "${found}" == "false" ]]; then
            errors="${errors}Invalid value for ${field}: '${value}' (valid: ${valid_values})\n"
        fi
    done

    echo -e "${errors}"
}

_schema_check_types() {
    local config_file="$1"
    local errors="$2"

    # Check that numeric fields are numeric
    local numeric_fields=(".night_watcher.interval_minutes" ".heartbeat.interval_seconds")
    for field in "${numeric_fields[@]}"; do
        local value
        value=$(yq eval "${field}" "${config_file}" 2>/dev/null) || value=""
        if [[ -n "${value}" && "${value}" != "null" ]]; then
            if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
                errors="${errors}Field ${field} must be numeric, got: '${value}'\n"
            fi
        fi
    done

    # Check that array fields are arrays
    local array_fields=(".integrations" ".communication.channels")
    for field in "${array_fields[@]}"; do
        local kind
        kind=$(yq eval "${field} | type" "${config_file}" 2>/dev/null) || kind=""
        if [[ -n "${kind}" && "${kind}" != "null" && "${kind}" != "!!seq" ]]; then
            errors="${errors}Field ${field} must be an array, got: ${kind}\n"
        fi
    done

    echo -e "${errors}"
}

# --- Public API ---

# Validate a configuration file against the expected schema.
# Returns 0 if valid, 1 if errors found. Prints errors to stdout.
# Usage: schema_validate <config_file>
schema_validate() {
    local config_file="${1:-${OTTO_HOME}/config.yaml}"

    if [[ ! -f "${config_file}" ]]; then
        log_error "Config file not found: ${config_file}"
        echo "Config file not found: ${config_file}"
        return 1
    fi

    if ! command -v yq &>/dev/null; then
        log_error "yq is required for schema validation"
        echo "yq is required for schema validation"
        return 1
    fi

    # Verify it's valid YAML first
    if ! yq eval '.' "${config_file}" &>/dev/null; then
        echo "Invalid YAML syntax in ${config_file}"
        return 1
    fi

    local errors=""
    errors=$(_schema_check_required "${config_file}" "${errors}")
    errors=$(_schema_check_enums "${config_file}" "${errors}")
    errors=$(_schema_check_types "${config_file}" "${errors}")

    # Trim whitespace
    errors=$(echo -e "${errors}" | sed '/^$/d')

    if [[ -n "${errors}" ]]; then
        log_warn "Configuration validation found errors:"
        echo "${errors}"
        return 1
    fi

    log_info "Configuration validated successfully: ${config_file}"
    return 0
}
