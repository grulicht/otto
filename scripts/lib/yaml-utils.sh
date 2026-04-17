#!/usr/bin/env bash
# OTTO - YAML utility functions (yq wrappers)

# Read a value from a YAML file
yaml_get() {
    local file="$1"
    local path="$2"
    local default="${3:-}"

    if [ ! -f "${file}" ]; then
        echo "${default}"
        return 0
    fi

    if ! command -v yq &>/dev/null; then
        log_warn "yq not installed, cannot read YAML"
        echo "${default}"
        return 0
    fi

    local value
    value=$(yq eval "${path}" "${file}" 2>/dev/null)
    if [ "${value}" = "null" ] || [ -z "${value}" ]; then
        echo "${default}"
    else
        echo "${value}"
    fi
}

# Set a value in a YAML file
yaml_set() {
    local file="$1"
    local path="$2"
    local value="$3"

    if ! command -v yq &>/dev/null; then
        log_error "yq not installed, cannot write YAML"
        return 1
    fi

    yq eval "${path} = ${value}" -i "${file}"
}

# Merge two YAML files (base + override)
yaml_merge() {
    local base="$1"
    local override="$2"

    if ! command -v yq &>/dev/null; then
        log_error "yq not installed, cannot merge YAML"
        return 1
    fi

    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${base}" "${override}"
}
