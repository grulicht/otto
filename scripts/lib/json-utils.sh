#!/usr/bin/env bash
# OTTO - JSON utility functions (jq wrappers)

# Read a value from a JSON file
json_get() {
    local file="$1"
    local path="$2"
    local default="${3:-}"

    if [ ! -f "${file}" ]; then
        echo "${default}"
        return 0
    fi

    local value
    value=$(jq -r "${path} // empty" "${file}" 2>/dev/null)
    echo "${value:-${default}}"
}

# Set a value in a JSON file
json_set() {
    local file="$1"
    local path="$2"
    local value="$3"

    if [ ! -f "${file}" ]; then
        echo "{}" > "${file}"
    fi

    local tmp
    tmp=$(mktemp)
    jq "${path} = ${value}" "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

# Set a string value in a JSON file
json_set_string() {
    local file="$1"
    local path="$2"
    local value="$3"

    json_set "${file}" "${path}" "\"${value}\""
}

# Append to a JSON array in a file
json_append() {
    local file="$1"
    local path="$2"
    local value="$3"

    if [ ! -f "${file}" ]; then
        echo "{}" > "${file}"
    fi

    local tmp
    tmp=$(mktemp)
    jq "${path} += [${value}]" "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

# Check if a JSON file contains a key
json_has() {
    local file="$1"
    local path="$2"

    [ -f "${file}" ] && jq -e "${path}" "${file}" &>/dev/null
}

# Pretty-print a JSON file
json_pretty() {
    local file="$1"
    jq '.' "${file}" 2>/dev/null
}
